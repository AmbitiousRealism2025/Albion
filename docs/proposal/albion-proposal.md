# Albion: Proposal for a GLM-5.2 Orchestration System Built Around Fable-Mode

**Version:** 0.1 (proposal for review)
**Date:** 2026-07-04
**Basis:** [Deep research analysis](../research/atreides-analysis.md) — 11-agent research mission over the Atreides repo, DeepWiki, the fable-mode-glm-5-2 skill, GLM-5.2's live documentation, and wire-level probes against the Z.ai endpoint.
**Companion:** [Visual companion (HTML)](albion-companion.html)

---

## 0. Thesis

Albion is the deliberate combination of three things that already exist but have never been joined:

1. **A working GLM-5.2 Claude Code environment** (`claude-glm-env.sh`, the `cglm` launcher) — Z.ai's Anthropic-compatible endpoint, opus-slot→glm-5.2 mapping, 1M context.
2. **The fable-mode-glm-5-2 skill** — an evidence-first operating discipline that counters GLM-5.2's exact documented failure modes (long-horizon drift, ungrounded progress claims, premature convergence).
3. **Atreides' model-agnostic orchestration IP** — intent gating, maturity assessment, delegation templates, exploration termination, completion gates — *stripped of its persona theater, its broken hook layer, and its Anthropic-coupled model routing.*

The organizing principle, dictated by the research: **GLM-5.2 inverts the enforcement equation.** Claude tolerated honor-system orchestration; GLM-5.2 (SWE-Marathon 13.0 vs Opus 4.8's 26.0, reward-hacking lineage, drift under long horizons) requires that every rule that *can* be enforced deterministically *is* enforced deterministically, and that everything left in the prompt is radically compressed.

### The four-layer division of labor

| Layer | Owns | Never does |
|---|---|---|
| **fable-mode skill** | Reasoning discipline: sustained reasoning, tool evidence, state definitions, hypotheses, verification, memory hygiene | Routing, enforcement, API configuration |
| **Albion charter** (always-on, <400 lines) | Routing & structure: intent gate → fable-on/off + effort tier, phase names, delegation template, workbench pointers | Restating fable-mode rules or native harness behavior |
| **Hook suite** | Enforcement: strike counting, completion blocking, destructive-command guard, secrets scrubbing, state re-injection | Semantic judgment (hooks are deterministic and blind) |
| **Launcher** | Configuration: endpoint, model IDs, effort defaults, context/output limits, cache hygiene, timeouts | Behavior |

Every rule is assigned to **exactly one layer**. Duplicating a rule across layers doubles drift surface — the documented Atreides pathology (two contradictory delegation templates, conflicting intent tables).

---

## 1. Repository & Deliverable Layout

Albion ships as a **Claude Code plugin** plus a thin launcher. No Handlebars, no npm-installed global state, no symlink hacks.

```
albion/
├── bin/
│   ├── albion                    # launcher (sources env, validates, execs claude)
│   └── albion-doctor             # health/contract verification CLI
├── env/
│   └── albion-env.sh             # GLM environment (successor to claude-glm-env.sh)
├── plugin/                       # the "albion" Claude Code plugin
│   ├── .claude-plugin/plugin.json
│   ├── skills/
│   │   ├── fable-mode-glm-5-2/   # behavioral core (v2, see §4)
│   │   ├── maturity-assessment/  # crown jewel #1
│   │   ├── delegation/           # crown jewel #2 (7-section template)
│   │   ├── recovery/             # crown jewel #3 (counterexample-first + strikes)
│   │   └── completion-gate/      # crown jewel #4 (NEVER/ALWAYS reference)
│   ├── agents/
│   │   ├── scout.md              # read-only explorer (effort: high)
│   │   ├── counterexample-hunter.md
│   │   ├── verifier.md           # fresh-context verification (effort: xhigh)
│   │   ├── simplifier.md
│   │   └── quick.md              # trivial tier (model: haiku → glm-5-turbo, thinking off)
│   ├── hooks/hooks.json          # the five enforcement hooks
│   └── scripts/                  # hook implementations (jq over stdin JSON)
├── charter/
│   └── ALBION.md                 # the <400-line always-on charter
├── manifest/
│   └── albion-manifest.yaml      # single source of truth → compiles charter/skills/docs
├── state/                        # session-state JSON engine (schema + helpers)
├── telemetry/                    # per-task metrics (ab-test-plan.md metrics, permanent)
├── bench/                        # internal regression benchmark (per model/provider bump)
└── docs/
```

**Distribution:** plugin marketplace entry (commit-SHA pinned) for the plugin; `albion` launcher installed to `~/bin`. `albion doctor` diffs installed assets against the package version manifest — the drift Atreides never detected becomes a checkable invariant.

---

## 2. Layer 1 — The Launcher (`albion`)

The launcher **sources** the GLM environment (Atreides' wrapper unset it — the single decision Albion reverses first) and execs Claude Code with the charter appended.

### 2.1 `env/albion-env.sh` (verified values)

```bash
# Endpoint — /api/anthropic, never /api/paas/v4 (documented silent failure mode)
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="${ZAI_API_KEY:?set ZAI_API_KEY}"

# Model slots — [1m] suffix is REQUIRED to unlock 1M context (client-side convention;
# raw API rejects it, Claude Code strips it and sets contextWindow=1000000)
export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2[1m]"   # Z.ai serves glm-5.2 for glm-5.1 anyway
export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5-turbo"    # the ONLY genuinely different tier

export API_TIMEOUT_MS=3000000
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=131072

# Cache hygiene (the 17k-token tool JSON is the largest cacheable asset; cached input $0.26/M)
export CLAUDE_CODE_ATTRIBUTION_HEADER=0               # removes uncached fingerprint block
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1     # kills background haiku-slot calls
export CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1

# Completion-gate budget (deliberate, not default)
export CLAUDE_CODE_STOP_HOOK_BLOCK_CAP=4

# ── LANDMINES (never set) ────────────────────────────────────────────
# CLAUDE_CODE_EFFORT_LEVEL   → overrides skill/agent frontmatter effort; collapses
#                              per-task routing to a session constant. Session default
#                              comes from settings.json "effortLevel" instead.
# MAX_THINKING_TOKENS=N      → ignored on the adaptive path (0 is meaningful: thinking off)
```

### 2.2 Modes (A/B evaluation is a first-class feature)

| Command | Environment | Purpose |
|---|---|---|
| `claude` | Anthropic, clean | Baseline / frontier lane |
| `albion` | GLM-5.2 + charter + plugin | The product |
| `albion --vanilla` | GLM-5.2, no charter/plugin | Control arm for the A/B loop |
| `albion --doctor` | — | Run the full health matrix, exit non-zero on any red cell |

### 2.3 Startup validation (fails loudly)

1. Endpoint reachable and is `/api/anthropic` (not `/api/paas/v4`).
2. A 1-token probe request returns model `glm-5.2` (catches silent server-side remapping — Z.ai has changed slot defaults post-launch before).
3. Claude Code version ≥ **2.1.163** (Stop additionalContext) — warn under 2.1.195 (matcher semantics).
4. Charter file resolves; every plugin hook responds correctly to a synthetic stdin payload (see §5.6).

---

## 3. Layer 2 — The Charter (`ALBION.md`, always-on, <400 lines)

The charter is what remains after moving reasoning discipline into the skill, enforcement into hooks, and configuration into the launcher. Target: **under 400 lines / ~3.5k tokens**. Contents:

### 3.1 Identity (3 lines, not 65)

```
You are Albion, an orchestration agent running GLM-5.2. Delegate liberally,
verify mechanically, claim nothing without evidence.
```

`CLAUDE_AGENT_NAME=Albion` supplies status-line identity. No mandatory response prefix — the research verdict is that prefix theater costs compliance budget GLM-5.2 cannot spare. A single announcement line at delegation boundaries only. *(A/B test persona-on vs persona-off before locking this.)*

### 3.2 The Intent Gate — Albion's core routing table

The single most important empirical finding: **abstract skill descriptions never auto-trigger under GLM-5.2 (0/3), while by-name invocation is fully reliable.** The gate is therefore the *trigger authority* for fable-mode, and it invokes the skill **by name**.

| Intent | Signals | Route | Effort tier | fable-mode |
|---|---|---|---|---|
| **Trivial** | lookup, one-liner, quick question | Answer directly or `quick` agent | thinking-off (haiku slot) | OFF (skill's own negative scope) |
| **Explicit** | clear requirements, known solution | Direct execution | high | OFF unless multi-file |
| **Exploratory** | "find/understand/where" | `scout` agent(s), parallel | high | OFF for scouts; ON for synthesis if complex |
| **Open-ended / long-horizon** | architecture, migration, ambiguous bug, multi-step | **Invoke `Skill(fable-mode-glm-5-2)` by name**, scaffold workbench | **max** (via skill frontmatter) | **ON — mandatory** |
| **Ambiguous** | unclear intent | One clarifying question, then reclassify | — | — |

Effort has exactly **three effective positions** through this endpoint (off / GLM-high / GLM-max; CC low/medium/high collapse to high, xhigh/max to max). The gate is a 3-way router — no finer gradations are promised, and thinking keywords are never used as routing signals (verified: they don't change the wire).

Routing is applied at **task boundaries** (skill/agent frontmatter — wire-verified), never by flipping `/effort` mid-session (cache invalidation risk).

### 3.3 Phase vocabulary — fable-mode's, not Atreides'

The two state machines are isomorphic; Albion keeps **one**:

**Scope Lock → State Map → Hypotheses → Staged Execution → Independent Verification → Report**

The charter carries only the phase names and gate rules (<50 lines). The full procedure lives in the skill. Atreides' transition semantics (what triggers movement between phases) carry over inside the new vocabulary.

### 3.4 Delegation (pointer + guard rails)

The canonical 7-section template (TASK / EXPECTED OUTCOME / CONTEXT / MUST DO / MUST NOT DO / TOOLS ALLOWED / SUCCESS CRITERIA) lives in the `delegation` skill and the agent definitions; the charter carries a 5-line reminder: delegate to named agents, one template, subagents don't spawn subagents, scouts return summaries not file dumps.

### 3.5 Task-tracking rule (kept deliberately)

Verified: GLM-5.2 **never self-initiates task tracking** but complies perfectly when instructed — and TodoWrite does not exist in current Claude Code (TaskCreate/TaskUpdate do). The charter keeps one explicit rule: multi-step work uses TaskCreate/TaskUpdate with in_progress→completed transitions. This is a rule that *cannot* be dropped as redundant.

### 3.6 What the charter deliberately does NOT contain

- Restated fable-mode rules (evidence discipline, workbench mechanics, recovery protocol)
- Restated native behavior (how subagents work, plan mode, permissions)
- References to TodoWrite/Grep/Glob (tools that no longer exist)
- Model-selection matrices (meaningless: Z.ai serves glm-5.2 regardless of opus/sonnet slot)
- Hardcoded model IDs (the fossilized `claude-3-opus-20240229` lesson)

---

## 4. Layer 3 — fable-mode-glm-5-2 v2 (the behavioral core, upgraded)

The skill's content survives nearly intact — the research validated its design against GLM-5.2's actual failure modes. The v2 changes are structural, wiring it into the harness:

### 4.1 Frontmatter (new)

```yaml
---
name: fable-mode-glm-5-2
description: >
  [unchanged prose, but auto-triggering is treated as decorative under GLM-5.2 —
  the Albion intent gate invokes this skill by name]
effort: xhigh            # wire-verified: skill frontmatter reaches output_config.effort
                         # → GLM reasoning_effort "max", Z.ai's own recommendation
hooks:                   # scoped to the skill's active lifetime, auto-cleaned
  SessionStart:
    - matcher: "compact|resume"
      hooks: [{ type: command, command: "${CLAUDE_PROJECT_DIR}/.albion/scripts/reinject-workbench.sh" }]
  Stop:
    - hooks: [{ type: command, command: "${CLAUDE_PROJECT_DIR}/.albion/scripts/fable-completion-gate.sh" }]
---
```

Invoking fable-mode now *automatically* escalates GLM-5.2 to `reasoning_effort: max` and arms the fable-specific gates — the run-config tiers the skill could only describe become mechanical.

### 4.2 Workbench fixes (the skill's unfinished edges)

- **Namespaced per task:** `.agent-workbench/fable-mode/<task-slug>/` — concurrent tasks no longer collide.
- **Hook-scaffolded:** a SessionStart/first-use hook creates the workbench from `templates/workbench-templates.md`, saving model tokens and guaranteeing structure.
- **Gitignored by default** (`albion init` adds `.agent-workbench/` — already done in this repo).
- **Lifecycle:** on completion-gate pass, the workbench is archived to `.albion/archive/<task-slug>/` and `lessons/` candidates are surfaced for promotion.
- **Secrets rule enforced:** PostToolUse `updatedToolOutput` scrubber on `.agent-workbench/**` writes (see §5.4) — the redaction note stops being advisory.

### 4.3 Content adjustments

- Replace "TodoWrite"-era references with TaskCreate/TaskUpdate semantics.
- Keep escalation phrases ("think hard") only as stylistic nudges — the skill no longer *pretends* they control effort; frontmatter does.
- The four subagent roles get one line each pointing to the real agent definitions (§6).
- The stop rule gains a sentence: "The Stop gate will block completion if verification.md is empty — fill it honestly, not to satisfy the gate." (Semantic honesty stays a prompt rule; existence/recency is the hook's job.)

---

## 5. Layer 4 — The Hook Enforcement Suite

Five hooks, all **command-type** (deterministic; prompt/agent hooks reserved as a future judgment layer), all exec-form with `${CLAUDE_PROJECT_DIR}`, all reading JSON from stdin, all integration-tested with recorded real payloads. Minimum Claude Code 2.1.163.

### 5.1 Destructive-command guard (PreToolUse)

- **Mechanism:** `hookSpecificOutput.permissionDecision: "deny"` + reason — **works even in bypassPermissions mode** (strongest primitive in the platform). Never the deprecated top-level decision fields.
- **Logic:** port Atreides' `validate-bash-command.sh` normalization pipeline verbatim (URL-decode, backslash-strip, hex/octal, quote-strip — it is genuinely good code that was never actually wired in).
- **Hard floor:** the permissions deny-list in settings.json, migrated to modern syntax (`Bash(rm:*)` etc.), keeping every obfuscation variant (`%72m`, `\rm`, `'rm'`, `command rm`, `/bin/rm`, `builtin eval`) and all secret-file Read/Write denies. Docs are explicit that the permission system, not hooks, is the guaranteed path — Albion uses both, deliberately layered.
- Implements fable-mode activation-contract rule 2 mechanically.

### 5.2 Strike counter (PostToolUse)

- Maintains per-operation failure counts in the session-state JSON (keyed by `session_id` from the hook input; operation = file + change type, Atreides' precise definitions).
- Injects via `hookSpecificOutput.additionalContext` (plain stdout is debug-only on this event), phrased as **factual state** — "Strike count: 2 of 3 on editing src/parser.ts" — because imperative out-of-band commands can trip injection defenses.
- On strike 3: injects the recovery protocol pointer — **counterexample-first** (log to counterexamples.jsonl, re-read task.md/state-map.md, shrink the next check), with git-revert demoted to escalation after repeated counterexample-loop failure. The hook counts; the model reasons.
- If parallel tool calls make per-call injection noisy, move to PostToolBatch (fires once per batch).

### 5.3 Completion gate (Stop)

The single most important conversion from honor system to mechanism — aimed squarely at GLM-5.2's reward-hacking lineage.

- **Blocks** (`{"decision":"block","reason":"<specific unchecked items>"}`) when session-state shows: open TaskCreate items; last recorded test/build failed; or — on fable-mode tasks — `verification.md` missing/empty or `evidence.md` lacks entries for claimed results.
- **Guards:** respects `stop_hook_active`; own on-disk attempt counter; `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP=4` set deliberately in the launcher; consults `background_tasks[]`/`session_crons[]` so it never fights a legitimately-waiting session.
- Uses `last_assistant_message` for a cheap "claimed done without evidence" heuristic (completion verbs + zero fresh tool output → block once with a pointed reason).
- Soft nudges use Stop `additionalContext` (renders as feedback, not error noise).

### 5.4 Workbench secrets scrubber (PostToolUse, matcher: Write|Edit on `.agent-workbench/**`)

- `updatedToolOutput` (shape-matched per tool, or it is silently ignored) + PreToolUse `updatedInput` for outbound redaction; `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` in the launcher.
- Documented honestly: scrubbing protects context and files, not transcripts/telemetry.

### 5.5 State re-injection (SessionStart, matchers: `startup|resume|clear|compact`)

- **The verified compaction-survival mechanism.** PreCompact injection does not exist (the Atreides `cat` hack targeted a channel that was never there); SessionStart with matcher `compact` is the documented, probe-confirmed channel — `additionalContext` arrives verbatim.
- Re-injects: `task.md` + `state-map.md` + open strike/task state + relevant `lessons/` — each payload under the 10,000-char cap or it degrades to a file-path preview.
- PostCompact hook refreshes the state files so the next injection is current.
- Static rules never travel this channel — CLAUDE.md/charter re-load natively after compaction.

### 5.6 The anti-inert-hook discipline (how Albion avoids Atreides' fate)

- Every hook has a **recorded-payload integration test**: pipe captured real event JSON in, assert exit code and JSON shape. (Atreides had 466 tests and zero against the wire format.)
- `albion doctor` runs the same suite against the *installed* hooks, verifies every hook appears in `/hooks` with the expected source, and greps a `--debug-file` session for "Executing hooks for".
- Iron rules encoded in CI: exit 1 never blocks; JSON is ignored on exit 2 (one signaling mode per hook); matchers are case-sensitive; subagent-dispatch matchers match `Task|Agent` (verified naming drift); 10k-char cap on all injected strings.

---

## 6. The Agent Roster

fable-mode's four named-but-undefined roles become real native subagents (`plugin/agents/*.md`), plus the trivial tier. All wire-verified mechanics: frontmatter `model:`/`effort:` reach the API per-task within one session.

| Agent | Frontmatter | Tools | Contract |
|---|---|---|---|
| `scout` | effort: high | Read-only (Read, Bash(read-only), WebFetch) | Question / Key Findings / Patterns / Recommendations, ≤500 words, scope tiers + termination criteria (convergence, sufficiency, 2 dry iterations) in the system prompt |
| `counterexample-hunter` | effort: xhigh | Read + test-run | Given a hypothesis, try to break it; output failing case or "no break found" with what was tried |
| `verifier` | effort: xhigh | Read + test-run | Fresh-context review of patch vs task.md + tests; never sees the implementation transcript |
| `simplifier` | effort: high | Read-only | Flags unnecessary abstraction and scope drift against task.md |
| `quick` | model: haiku (→ glm-5-turbo), thinking auto-off | Minimal | The trivial tier — cheapest lane by price and quota |

Delegation economics invert Atreides' caution: forked exploration runs GLM-5.2 at 3.6–5.7× below Opus pricing, so Albion is *more* aggressive with parallel scouts. The main agent keeps working while subagents run (SKILL.md line 207), then reconciles.

**Optional frontier lane:** for novel-architecture or security-critical review ("~6 months behind frontier" consensus), a separately-spawned `claude` CLI process (session-level binding makes in-session mixing impossible). Declared, optional, off by default.

---

## 7. State & Memory Model

Two systems with distinct masters, by design:

| | Workbench (prose) | Session-state (JSON) |
|---|---|---|
| Written by | The model (fable-mode discipline) | **Hooks** (never the model) |
| Read by | The model | Hooks (Stop gate, strike counter) + SessionStart re-injection |
| Contents | task.md, state-map.md, hypotheses.md, evidence.md, verification.md, counterexamples.jsonl, lessons/ | sessionId, phase, per-operation strike counts, task states, last test/build result, tool history summary |
| On disagreement | — | **JSON wins** (it is mechanically derived) |

Long-term memory: workbench `lessons/` (task-scoped, promoted deliberately) + native CLAUDE.md hierarchy with path-scoped `.claude/rules/`. The mem0/Cipher/Qdrant/Forge service chain is dropped entirely; if cross-session semantic memory proves necessary, it returns as **one declared MCP server** with a doctor-checkable health command. Auto-memory stays disabled initially (GLM note-generation quality unknown).

Context economics: treat the 1M window as **headroom, not a working set** — aggressive scout summarization, workbench re-anchoring, compaction well before the extremes.

---

## 8. Telemetry & the Continuous Experiment

Both foundations are unvalidated (fable-mode has an A/B plan with no results; GLM benchmarks are self-reported). Albion resolves this by building the experiment into the product:

- **Per-task telemetry** (from Milestone 2): the ab-test-plan.md metrics become permanent — ungrounded-claim count (Stop-gate heuristic hits), scope-drift flags (simplifier findings), counterexamples discovered, strikes, time-to-first-useful-patch, tokens by model (from `usage`/`modelUsage` — Claude Code's `total_cost_usd` is wrong under Z.ai and is ignored).
- **Three-arm comparison** built into the launcher: `albion` vs `albion --vanilla` vs `claude` on the same task classes.
- **Internal regression bench** (`bench/`): representative repo tasks with ground-truth checks, re-run on every model bump (Z.ai ships ~every 2 months and silently changes slot defaults) and per provider (quantized third-party hosts may silently degrade compliance behaviors).

---

## 9. Cost Model & Plan Recommendation

Measured/derived (report [10](../research/reports/10-effort-routing-and-costs.md)):

- Always-on prefix (tools JSON ~17.4k + system + charter + skill + workbench re-injection) ≈ **30–32k tokens** → ~$0.045 first pass, **~$0.008/turn cached** ($0.26/M cached input). On a Coding Plan this is quota-free (prompts are metered, not tokens).
- Medium fable-mode task (30 tool calls + 4 subagents ≈ 55 model calls, ~2.3M input tokens ~93% cached, ~100k output): **≈ $1.20 API warm cache / $3.65 cold** ≈ **3 prompt-equivalents** (≈9 at peak 3×).
- **Recommendation: GLM Coding Plan Lite ($18/mo, promo ~$12.60)** — ~80 prompts/5h ≈ 9 (peak) to 25+ (off-peak) medium tasks per window. Upgrade to Pro for parallel fan-out workloads, sustained peak-hour use (14:00–18:00 UTC+8), or >100 MCP calls/mo. Keep an API key as overflow.
- The real cost hazards are **Stop-hook re-prompt loops** (each iteration is a full-context call and a prompt-equivalent — hence the hard cap of 4) and **cache breakage** (MCP churn, version bumps, mid-session effort flips).

---

## 10. Roadmap

| Milestone | Deliverable | Exit criteria |
|---|---|---|
| **M0 — Verification** *(largely complete via research probes)* | Filled feature matrix under Z.ai | Remaining cells: cache-keying on effort (2 paired requests), subagent prompt-accounting, current Pro/Max pricing |
| **M1 — Launcher + doctor** | `bin/albion`, `env/albion-env.sh`, `albion doctor` | Doctor passes on this machine; wrong-endpoint/model/version fail loudly; synthetic payloads pass through all hooks |
| **M2 — Hooks + state engine** | Five hooks + session-state JSON + recorded-payload test suite | Stop gate demonstrably blocks a fake "done"; strike counter injects at 2; scrubber redacts a planted secret |
| **M3 — Charter + skills + agents (plugin)** | ALBION.md <400 lines, fable-mode v2, 4 crown-jewel skills, 5 agents, plugin manifest | One-command install; gate invokes fable-mode by name on a long-horizon task end-to-end |
| **M4 — Telemetry + bench** | Per-task metrics, three-arm A/B, regression bench | First A/B report: albion vs vanilla-GLM on 8–12 tasks (the ab-test-plan.md experiment, finally run) |
| **M5 — Hardening** | Provider abstraction (data-sovereignty toggle), frontier review lane, lessons-promotion flow | Bench green across ≥2 providers or documented variance |

Suggested cadence: M1–M2 are a week of focused work; M3 a second week; M4 runs continuously from M2 onward.

---

## 11. Risks & Open Questions

1. **Charter-size hypothesis** — <400 lines is a target, not a finding; GLM's compliance-vs-coverage curve bend is unmeasured. Mitigation: A/B compliance probes in the bench.
2. **Gate misclassification** — if the intent gate misses "complex", fable-mode never engages (the always-on gate is the fallback for unreliable auto-triggering, but the gate itself can drift). Mitigation: user override (`/fable-mode` explicit invocation always works — verified), telemetry on gate decisions.
3. **Z.ai ground movement** — silent slot remapping, bimonthly model bumps, promo-dependent pricing. Mitigation: doctor probe on startup + bench per bump.
4. **Prompt-accounting ambiguity** — whether subagent spawns and Stop-hook turns draw down prompt quota is undocumented. Planning assumption: call-budget draw-down (~15–20 calls/prompt).
5. **Quantized-provider variance** — behavior guarantees are validated on first-party serving only until the bench runs per-provider.
6. **Hook semantic blindness** — a gamed gate (`touch verification.md`) passes mechanically. Mitigation: honesty stays a skill rule; gate checks recency/size heuristics, not just existence; verifier agent is the semantic layer.
7. **Data sovereignty** — first-party Z.ai routes code through Chinese servers; this is a per-project decision the provider toggle must surface, not bury.

---

## 12. What Success Looks Like

Six months in, Albion is judged by:

- **Reliability:** ungrounded-claim rate and premature-completion rate near zero on instrumented tasks (the Stop gate makes the second structurally difficult).
- **Throughput-per-dollar:** medium tasks at ~$0–marginal cost on Lite quota that would cost $5–15 on frontier API pricing.
- **Survivability:** model bumps and CC version bumps produce bench diffs, not silent regressions.
- **The experiment answered:** the first real data on whether fable-mode measurably improves GLM-5.2's long-horizon discipline — the question the skill's A/B plan asked and never answered.

---

*Prepared by the Albion research mission. Next step: review this proposal, then move to planning (Milestone 1 breakdown).*
