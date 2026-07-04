# Atreides Under the GLM-5.2 Lens
## Deep Research Analysis for the Albion Orchestration System

**Date:** 2026-07-04
**Mission:** Analyze the Atreides orchestration framework — its codebase, behavioral layer, and documented architecture — through the lens of rebuilding it as **Albion**: a next-generation orchestration system for Claude Code where the main model is Z.ai's **GLM-5.2** and the behavioral core is the **fable-mode-glm-5-2** skill.
**Method:** 11-agent research workflow (6 parallel deep-dives → gap-analysis synthesis → completeness critic → 3 follow-up agents, including **live wire-level probes against the Z.ai endpoint**). The full raw agent reports are retained by the maintainer outside the public repo (they contain machine-specific environment details); this analysis is the complete synthesis of their findings.

---

## 1. Executive Summary

Five findings dominate everything else in this analysis:

1. **Atreides enforces almost nothing.** Its five security/enforcement hook scripts read `$1`/`$TOOL_INPUT` environment variables and block with exit code 1 — but real Claude Code delivers hook input as **JSON on stdin** and blocks with **exit code 2**. The entire hook enforcement layer has been silently inert in live sessions; 466 Jest tests never exercised the real wire format. The only layer that actually enforces is the `settings.json` permissions deny-list (and even that uses a pre-modern wildcard syntax). Atreides worked as pure prompt engineering on a model (Claude) whose agentic post-training tolerated it.

2. **GLM-5.2 inverts the enforcement equation.** GLM-5.2 is the top open-weights agentic coder (SWE-bench Pro 62.1 vs Opus 4.8's 69.2, at 3.6–5.7× lower price) — but it scores **half of Opus on SWE-Marathon (13.0 vs 26.0)**, the ultra-long-horizon benchmark. Its documented failure modes (long-session drift, verbosity, reward-hacking lineage, ungrounded progress claims) are exactly what the fable-mode skill was designed to counter. Everything Atreides *trusted the model to do* (count strikes, audit todos, refuse premature completion) must move into deterministic hooks; everything that must stay prompted must be radically compressed, because long rule lists degrade GLM compliance faster than Claude's.

3. **Albion already half-exists on this machine — as two halves that have never met.** `~/.local/bin/claude-glm-env.sh` (the `cglm`/`cgly` launchers) already runs Claude Code against Z.ai's Anthropic-compatible endpoint with opus→glm-5.2 model mapping. `~/bin/atreides` runs the orchestration profile — and **explicitly unsets the GLM environment** to force Anthropic. Albion is, literally, the missing combination.

4. **Empirical verification (live probes, Claude Code 2.1.197 against api.z.ai) settles the critical unknowns.** Hooks, native subagents, plan mode, chained tool sequences, and per-subagent effort/model routing all **work** under GLM-5.2. The decisive negative: **description-based skill auto-triggering fails for abstract descriptions (0/3)** while explicit by-name invocation is fully reliable — so Albion's intent gate must invoke fable-mode **by name**, deterministically.

5. **fable-mode and Atreides are structurally isomorphic — and Albion is fable-mode's missing half.** The skill is a pure honor system: named-but-undefined subagents, an un-namespaced workbench, an unenforced secrets rule, and API parameters (`reasoning_effort`) it cannot set itself. Atreides' phase machine maps 1:1 onto fable-mode's operating loop. Albion should adopt **one vocabulary** (fable-mode's), supply the enforcement hooks, agent definitions, effort routing, and scaffolding the skill explicitly leaves to "the harness," and never run two competing workflow state machines in GLM-5.2's context.

---

## 2. Anatomy of Atreides

### 2.1 What it is

Atreides ships as the npm package `muaddib-claude` (repo v1.0.6, installed instance v1.0.5-era). It is a **prompt-injected orchestration layer**: a Handlebars-templated CLAUDE.md (~1,398 lines generated in v1.0.6, down from ~4,000), a settings.json with 5 hook events and a ~70-entry permission deny-list, five bash hook scripts, and 11 flat-markdown "skills" symlinked into `~/.claude/skills`. The orchestrator persona ("Muad'Dib") classifies every request into 5 intent categories, routes it through a 5-phase workflow (Intent Gate → Assessment → Explore/Implement/Recover → Completion), delegates to 9 named subagent types via a 7-section dispatch template, and enforces a 3-strikes error-recovery protocol — **all via prompt, none via code**.

### 2.2 The implementation layer (report 01)

| Subsystem | State |
|---|---|
| Hook scripts (validate-bash-command.sh, pre-edit-check.sh, error-detector.sh, post-edit-log.sh, notify-idle.sh) | Sophisticated (multi-stage obfuscation normalization, secret-file blocklists) but **silently inert** — wrong input contract (`$1`/env vars vs JSON-on-stdin) and wrong exit codes (1 vs 2) |
| Permissions allow/deny list | **The real enforcement layer.** ~70 deny entries incl. obfuscation variants (`%72m`, `\rm`, `'rm'`, `command rm`, `/bin/rm`, `builtin eval`) + secret-file Read/Write denies. Uses legacy `Bash(npm *)` space-wildcard syntax |
| Settings merge / config safety code | **Best-tested code in the repo**: matcher-level hook merging with signature dedup, prototype-pollution-safe deepMerge, path-traversal guards, DoS caps, backup rotation |
| Handlebars template engine | 16 helpers + 16 partials to vary essentially one field (projectType) — heavy machinery for static output, and the partials/lib/skills triplication caused documented contradiction drift |
| Skills | Flat .md files with **invented frontmatter** (`context: fork`, `agent:`, `model:`, `hooks:`) that Claude Code never honored |
| Dual-environment wrapper | `~/bin/atreides` cats a profile CLAUDE.md and execs `claude --append-system-prompt` — proven pattern; duplicates the identity rule at top AND bottom as an adherence hack |
| Installed instance | **Drifted**: `~/.atreides` runs v1.0.5-era skills against a v1.0.6 repo, plus undeclared accretions — mem0 Python venv, Cipher/Ollama/FAISS memory, Docker+Qdrant, a Forge adapter over Tailscale, and an unpublished JSON session-state engine |

### 2.3 The behavioral layer (report 02)

The genuinely valuable, model-agnostic prompt IP ("crown jewels"):

1. **Maturity-assessment rubric** — 13-point scored rubric → GREENFIELD/TRANSITIONAL/DISCIPLINED/LEGACY, each with concrete behavior-modification tables. No native Claude Code equivalent exists. The most original IP in the system.
2. **7-section delegation template** — TASK / EXPECTED OUTCOME / CONTEXT / MUST DO / MUST NOT DO / TOOLS ALLOWED / SUCCESS CRITERIA, with "Do NOT spawn additional sub-agents" guards. (Two contradictory versions exist in the repo — evidence of duplicated-prose drift.)
3. **3-strikes recovery protocol** — precise strike/reset definitions; STOP → REVERT → DOCUMENT → CONSULT → ESCALATE.
4. **Exploration termination criteria** — stop on convergence, sufficiency, or 2 no-new-info iterations; scope-based iteration budgets. Absent from native Claude Code.
5. **Completion NEVER/ALWAYS gate** — 4-step audit + absolute rules (never stop with incomplete todos / failing tests), PASS/FAIL report with severity levels.

Also validated by Atreides' own history: the **v1.0.6 progressive-disclosure architecture** (4,000 → 1,398-line CLAUDE.md, 12 of 15 partials moved to an on-demand reference skill) proved that the monolith fails — and GLM-5.2 raises those stakes.

What is now redundant: TodoWrite discipline rules, parallel-Task mechanics, quality-standard boilerplate, per-language lint/test tables — *conditional on verification*, which the live probes largely supplied (see §5).

### 2.4 What DeepWiki adds (report 03)

The DeepWiki (28 pages fetched) confirms the architecture and surfaces the drift record: contradictory skill counts (11 vs 12), **two different "7-section delegation templates"**, conflicting intent-routing tables between pages, a fossilized obsolete model ID (`claude-3-opus-20240229` hardcoded in workflow-phases.hbs), and the admission that the PreCompact `cat` hack is only "likely" to survive compaction. The lesson for Albion: **one source-of-truth manifest, compiled to charter + skills + docs** — never parallel markdown copies.

---

## 3. The fable-mode-glm-5-2 Skill (report 04)

The skill (6 files, 2026-07-02) converts publicly observable Fable operating patterns into an external discipline for GLM-5.2, targeting its core failure mode: cheap long-horizon reasoning degrading into **"token fog"** — scope drift, premature convergence, overloaded-term confusion, ungrounded progress claims.

Three stacked mechanisms:

- **6-rule activation contract** — autonomy on reversible actions; pause on destructive/scope/secrets; analysis-means-no-fix; no scope creep; **no unevidenced progress claims** (the load-bearing rule, stated twice); no raw reasoning exposure.
- **7-artifact workbench** (`.agent-workbench/fable-mode/`) — task.md (scope lock), state-map.md (semantic ledger + boundary probes + "danger lantern" names), hypotheses.md (competing theories with falsifiers), evidence.md (claims with sources), verification.md, counterexamples.jsonl ("contradiction is a steering event"), lessons/.
- **6-stage operating loop** — Scope Lock → State Map → Competing Hypotheses → Small Coherent Stages → Independent Verification → Memory Hygiene, plus an outcome-first communication style, a stop rule, and counterexample-first failure recovery.

It names four subagent roles (**scout, counterexample-hunter, verifier, simplifier**) but never defines them as agents; prescribes run-config tiers (`reasoning_effort: max`/65536 hard, `high`/32768 medium, thinking-off/4096 trivial) that **a skill cannot set itself**; and ships an A/B test plan with **no recorded results**. It was drafted for GLM as a *secondary* workhorse in Codex-style environments — Albion promotes it to the main model's operating system.

**Unfinished edges Albion must fix:** no enforcement (pure honor system), fixed non-namespaced workbench path (concurrent tasks collide), no workbench lifecycle/gitignore guidance, an unenforced secrets-redaction note, no subagent definitions, ambiguous memory location.

**Direct conflicts with Atreides-as-is:** 3-strikes git-revert recovery vs counterexample-first recovery; sonnet/opus model table (meaningless under GLM); TodoWrite+checkpoint.md vs workbench (triple bookkeeping); the triple-repeated `[Muad'Dib]:` prefix mandate competing for GLM's limited compliance budget.

---

## 4. GLM-5.2 Capability Profile (report 05)

Shipped to GLM Coding Plan subscribers **June 13, 2026**; MIT open weights + API June 16–17. ~744–753B-parameter MoE (~40B active), 1M-token context ("truly usable", via IndexShare sparse attention), ~128K output, two reasoning-effort levels (high/max), trained with explicit anti-reward-hacking RL.

### 4.1 Benchmarks vs Claude

| Benchmark | GLM-5.2 | Claude Opus 4.8 | Note |
|---|---|---|---|
| SWE-bench Pro | **62.1** | 69.2 | Top open-weights; above GPT-5.5 (58.6) |
| Terminal-Bench 2.1 | **81.0** | 85.0 | Huge jump from GLM-5.1 (62.0) |
| FrontierSWE | **74.4** | 75.1 | Near-parity |
| **SWE-Marathon** | **13.0** | **26.0** | **Half of Opus — the long-horizon gap Albion lives on** |
| Design Arena | **#1 (Elo 1360)** | below | Best-in-class frontend/design |

Caveat: headline numbers are self-reported by Z.ai; independent verification was pending as of July 2026.

### 4.2 Operational profile

- **Pricing:** API $1.40/M input, $0.26/M cached input, $4.40/M output (≈3.6–5.7× cheaper than Opus). Coding Plan: Lite $18/mo (~80 prompts/5h), Pro $72 (~400), Max $160 (~1,600); 3× quota multiplier at peak (14:00–18:00 UTC+8).
- **Strengths:** routine agentic coding, frontend/design, multi-step instruction following, genuinely usable long context, cost.
- **Weaknesses (user-reported):** long-session drift ("goes off-script"), novel-architecture reasoning ("~6 months behind frontier"), verbosity, slow peak-hour first-party serving, subtle tool-response handling differences, weak non-coding prose (#25 Text Arena).
- **Data sovereignty:** Z.ai first-party routes code through Chinese servers; mitigations are US-resident hosts of the open weights (often FP8/FP4 quants with quality variance) or self-hosting (~714GB at 4-bit).
- **No per-message model mixing:** once `ANTHROPIC_BASE_URL` points at Z.ai, the whole session (including all native subagents) is GLM-backed.

The weaknesses map almost exactly onto the deficits fable-mode is designed to compensate for — **strong validation of Albion's core premise**.

---

## 5. Empirical Verification: What Actually Works Under GLM-5.2 (reports 08, 09, 10)

The completeness critic flagged that the design rested on unverified assumptions, so follow-up agents **ran the verification matrix live** (Claude Code 2.1.197, real Z.ai token) and extracted the current hooks contract at field level.

### 5.1 The verification matrix (live probes)

| Feature | Result |
|---|---|
| Skill auto-trigger, distinctive lexical description | ✅ 3/3 — real Skill tool call, instruction obeyed |
| Skill auto-trigger, abstract fable-style description | ❌ **0/3 — even when the prompt quoted the description's own vocabulary** |
| Explicit skill invocation (`/name` or "use the X skill") | ✅ 2/2 fully reliable |
| Native subagents (`.claude/agents/*.md`), incl. proactive dispatch | ✅ Works; note: tool listed as `Task` but tool_use blocks named `Agent` — hook matchers must match both |
| PreToolUse exit-2 blocking | ✅ Works; GLM quotes the block reason and does not thrash |
| Stop hook `decision:block` | ✅ Forces continuation; `stop_hook_active` loop guard works |
| SessionStart `additionalContext` | ✅ Injected verbatim and visible to GLM |
| Per-subagent `model:`/`effort:` frontmatter | ✅ **Captured on the wire**: subagent ran glm-5-turbo/effort-low/thinking-omitted while main stayed glm-5.2/xhigh/adaptive |
| Chained multi-tool sequences (search→read→edit) | ✅ Clean, incl. recovery from empty first result |
| Plan mode (headless) | ⚠️ Permission enforcement works; `ExitPlanMode` absent in `-p` mode |
| TodoWrite / Grep / Glob | ❌ **Do not exist in CC 2.1.197** — TaskCreate/TaskUpdate replace todos; GLM adapts perfectly when instructed, but never self-initiates task tracking |
| Model tiers on Z.ai | ⚠️ Z.ai **silently serves glm-5.2 for glm-5.1/glm-5 requests** — only glm-5-turbo is genuinely different; opus/sonnet tiering is cosmetic |
| `[1m]` context suffix | Client-side convention: raw API rejects `glm-5.2[1m]` (error 1211); through Claude Code it sets contextWindow=1,000,000 |
| Cost accounting | ❌ Claude Code applies Anthropic price tables to GLM tokens — only token counts are trustworthy |

### 5.2 The hooks contract (field-level, July 2026 docs)

- **PreCompact does NOT inject context** (resolves a contradiction between research streams — the Atreides `cat` hack was aimed at a channel that doesn't exist). The documented compaction-survival mechanism is a **SessionStart hook with matcher `compact`**, whose stdout IS added to context.
- Stop gate: exit 0 + `{"decision":"block","reason":"..."}`; `stop_hook_active` guard; 8-consecutive-block cap (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`); `last_assistant_message` available for "claimed done without evidence" heuristics.
- PostToolUse: `hookSpecificOutput.additionalContext` lands next to the tool result (the channel for strike injection); `updatedToolOutput` can replace what the model sees (the channel for secrets scrubbing). Plain stdout is NOT injected on this event.
- PreToolUse: `permissionDecision: deny` **blocks even in bypassPermissions mode** — the strongest enforcement primitive in the platform. Exit 1 never blocks anything.
- Hooks can be declared in **skill/agent YAML frontmatter**, scoped to the component's lifetime — fable-mode can ship its own enforcement hooks that activate exactly when the skill is active.
- All injected strings cap at 10,000 chars; exec-form commands with `${CLAUDE_PROJECT_DIR}` avoid shell-quoting breakage; minimum viable version for Albion's gate design: **Claude Code ≥ 2.1.163** (2.1.195+ preferred).

### 5.3 Effort routing and cost model

- Claude Code sends `thinking:{type:"adaptive"}` + `output_config:{effort:...}` even for unrecognized model IDs behind `ANTHROPIC_BASE_URL`; Z.ai accepts both. Official mapping: CC low/medium/high → GLM `high`; xhigh/max/ultracode → GLM `max`. **Three effective tiers: thinking-off / high / max.**
- Per-task routing lives in **subagent/skill frontmatter** (proven on the wire). `CLAUDE_CODE_EFFORT_LEVEL` env var **overrides frontmatter** and must never be set by the launcher. `ultrathink`-style keywords do not change transmitted effort.
- `clear_thinking` and `tool_stream` are unreachable through the Anthropic-compatible endpoint (native API only).
- Albion's always-on prefix measures ~30–32k tokens ≈ $0.045 first pass / ~$0.008 per cached turn. A medium fable-mode task (30 tool calls + 4 subagents ≈ 55 model calls) ≈ **$1.20 API with warm cache** ($3.65 cold) ≈ **3 prompt-equivalents** on a Coding Plan. **Lite ($18/mo) covers ~9 (peak) to 25+ (off-peak) such tasks per 5-hour window** — the right starting tier.
- Cache hygiene is budget-critical: stable tool/MCP set (the 17k-token tool JSON is the largest cacheable asset), `CLAUDE_CODE_ATTRIBUTION_HEADER=0`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`, pinned CC version, effort routed at task boundaries rather than mid-session flips.

---

## 6. Component Verdict Map

Every Atreides subsystem, mapped to a verdict for Albion. (Full rationale per component in report 07.)

| # | Component | Verdict | Albion design |
|---|---|---|---|
| 1 | Muad'Dib persona + mandatory `[Muad'Dib]:` prefix | **Replace** | One-line identity + `CLAUDE_AGENT_NAME=Albion`; single announcement at delegation boundaries; A/B test persona-on/off |
| 2 | 5-phase workflow state machine | **Replace** | Adopt fable-mode's vocabulary as canonical: Scope Lock → State Map → Hypotheses → Staged Execution → Independent Verification → Report |
| 3 | Phase 0 intent classification (5 categories) | **Modernize** | Keep taxonomy; each category now outputs fable-on/off + effort tier; gate invokes fable-mode **by name** |
| 4 | Maturity-assessment rubric (13-point, 4 levels) | **Keep** | Compact on-demand skill; output feeds state-map.md |
| 5 | 3-strikes recovery protocol | **Modernize** | PostToolUse hook counts strikes in session-state JSON, injects "STRIKE 2 of 3"; counterexample-first recovery primary, git-revert demoted to escalation |
| 6 | 7-section delegation template | **Keep** | One canonical version in a manifest, compiled everywhere; wire format for fable's subagent roles |
| 7 | 9-agent roster + sonnet/opus routing | **Replace** | Route by **mode + effort**, not model; ship scout/counterexample-hunter/verifier/simplifier as native agents; optional Claude-backed review lane for novel-architecture/security work |
| 8 | Forked-context exploration pattern | **Modernize** | Native scout subagent with read-only tools, word-capped output contract, termination criteria; GLM pricing allows *more* parallel exploration |
| 9 | Skills packaging (flat .md, invented frontmatter, symlinks) | **Replace** | Real SKILL.md directories in an `albion` plugin; commit-SHA pinned; every skill also user-invocable |
| 10 | Hook scripts (5 bash scripts) | **Replace** | Rebuild on the real contract (JSON stdin, exit 2 / permissionDecision); port the normalization pipeline logic verbatim; integration-test with real payloads |
| 11 | Permissions deny-list | **Modernize** | Port nearly verbatim, migrated to `Bash(cmd:*)` syntax; keep all obfuscation variants |
| 12 | Phase 3 completion gate | **Modernize** | Stop hook mechanically blocks termination on open tasks / failed tests / empty verification.md — the single most important conversion from honor system to mechanism |
| 13 | 3-tier context files + PreCompact cat hack | **Replace** | Unify on the fable workbench (namespaced, gitignored, hook-scaffolded) + SessionStart(matcher: compact) re-injection |
| 14 | Session-state JSON engine (prototyped, unreleased) | **Modernize** | Ship it: hook-facing JSON complement to the model-facing workbench prose |
| 15 | Handlebars template engine | **Drop** | Static files per project type from a single source-of-truth manifest; keep JSON merge only for settings.json |
| 16 | Settings-merge & safety utilities | **Keep** | Port directly into the albion CLI |
| 17 | Installer/CLI lifecycle (install/init/update/doctor) | **Modernize** | Plugin-first; version manifest; `albion doctor` pipes synthetic payloads through every hook and validates endpoint/model |
| 18 | Dual-environment wrapper | **Modernize** | `albion` wrapper **sources** claude-glm-env.sh (instead of unsetting it); modes: `claude` / `albion` / `albion --vanilla` for A/B |
| 19 | GLM environment plumbing (claude-glm-env.sh) | **Keep** | Promote to Albion's core bootstrap; pin `glm-5.2[1m]`; startup validation fails loudly |
| 20 | External memory sprawl (mem0/Cipher/Qdrant/Forge) | **Drop** | Memory = workbench lessons/ + native CLAUDE.md hierarchy + path-scoped rules; one declared MCP server later if needed |
| 21 | Progressive-disclosure prompt architecture | **Keep** | Push further: always-on charter well under ~400–500 lines; everything else on-demand |

**Tally: 5 keep · 8 modernize · 6 replace · 2 drop.**

---

## 7. Design Tensions the Proposal Must Resolve

1. **Trigger authority** — description-based auto-triggering is proven unreliable for abstract skills under GLM-5.2, so the always-on intent gate must own fable-on/off — which partially resurrects the always-on prompt Albion wants to shrink.
2. **Hooks vs skill instructions as enforcement substrate** — hooks are deterministic but semantically blind (they can check verification.md is non-empty, not that it constitutes real verification); prompts are rich but honor-system, and GLM's reward-hacking lineage makes honor systems specifically risky. Every rule must be assigned to exactly one layer.
3. **The compliance-vs-coverage curve** — GLM needs *more* explicit structure precisely because it complies *worse* with long rule lists. The <400–500-line charter is a hypothesis to A/B test, not a finding.
4. **Context budget & cache economics** — charter + SKILL.md + workbench re-injection + project CLAUDE.md compete for the same prefix; loading fable-mode on demand saves trivial-turn tokens but perturbs the cached prefix on complex ones.
5. **Two state systems** — prose workbench (model-facing) vs session-state JSON (hook-facing). Hooks can't parse prose; some dual bookkeeping survives. Resolution: hooks write the JSON; prose stays the model's medium; JSON wins on disagreement.
6. **Failure-recovery philosophy** — counterexample-first (fable) vs revert-first (Atreides). Resolution: counterexample-first primary, revert as escalation; thresholds must be defined (how many counterexample loops before revert, who counts — the hook).
7. **Session-level model binding vs task-level routing ambitions** — no per-message GLM/Claude mixing; a Claude review lane requires separately spawned CLI processes.
8. **API knobs the skill can't reach** — effort is routable via frontmatter (verified); `clear_thinking`/`tool_stream` are not reachable at all through this endpoint.
9. **Bounded autonomy vs orchestration ambition** — SWE-Marathon says decompose into short verified segments; Albion's purpose is long-horizon work. Segment budgets and checkpoint semantics are a product decision.
10. **Two unvalidated foundations** — fable-mode has an A/B plan with no results; GLM-5.2 benchmarks are self-reported. Resolution: build the harness, convert ab-test-plan.md's metrics into permanent per-task telemetry, run the three-mode wrapper as a continuous experiment.
11. **Native-feature dependence** — every "drop the redundant prompt rule" verdict is conditional on a green verification cell; the architecture must tolerate per-feature verdict reversals. (Most cells are now green — see §5.1.)
12. **Data sovereignty vs behavior guarantees** — provider toggles are easy; guaranteeing consistent fable-mode compliance across quantized third-party hosts is not. The internal regression benchmark must run per-provider.

---

## 8. The Division of Labor (the architecture in one paragraph)

**fable-mode owns reasoning discipline** (sustained reasoning, tool evidence, state definitions, memory hygiene, verification). **The Albion charter owns routing and structure** (intent classification → fable-on/off + effort tier, phase gate names, delegation template, workbench pointers). **Hooks own enforcement** (strike counting, completion blocking, destructive-command guards, secrets scrubbing, state re-injection). **The launcher owns configuration** (endpoint, model IDs, effort defaults, cache hygiene, timeouts). Every carried-over Atreides rule gets audited against fable-mode for duplication — Atreides paid a 1,729-line dedup cleanup for violating exactly this.

---

## 9. Sequencing Implied by the Research

- **Milestone 0 — Verification matrix: largely complete.** The live probes filled most cells (§5.1); remaining unknowns are small (whether Z.ai's cache keys on effort; exact subagent prompt-accounting; Pro/Max promo pricing).
- **Milestone 1 — Launcher + doctor.** Endpoint/model validation, synthetic hook payload testing, version manifest diffing — directly addressing how Atreides' inert hooks and install drift went undetected for months.
- **Milestone 2 — Hook suite + session-state engine.** The five enforcement hooks against the verified contract.
- **Milestone 3 — Charter + skills + agents as a plugin.**
- **Milestone 4 — Telemetry loop** (from M2 onward): with a model that ships a new version roughly every two months and silently changes defaults, Albion's real moat is not its prompt — it is its ability to notice when the ground moves.

---

## Appendix: Full Agent Reports

The raw reports below are retained locally by the maintainer and excluded from the public repository (they document a specific machine's environment). Their substantive findings are fully incorporated above.

| Report | Contents |
|---|---|
| 01-atreides-codebase.md | Implementation layer: installer, hooks, templates, security scripts, installed-instance drift |
| 02-atreides-behavior-layer.md | Behavioral/prompt layer: phases, intent, maturity, delegation, completion, continuity |
| 03-atreides-deepwiki.md | DeepWiki extraction (28 pages): documented architecture + drift record |
| 04-fable-mode-skill.md | fable-mode-glm-5-2: mechanisms, rationale, conflicts, amplification points |
| 05-glm-5.2-capabilities.md | GLM-5.2: architecture, benchmarks, setup mechanics, strengths/weaknesses, pricing |
| 06-claude-code-modern.md | Modern Claude Code surface: skills, plugins, subagents, hooks, settings, memory, MCP |
| 07-gap-analysis.md | Synthesis: verdict map narrative + division of labor |
| 08-verification-live-probes.md | Live milestone-zero probes against Z.ai (skills, subagents, hooks, plan mode, effort) |
| 09-hooks-contract.md | Field-level hooks contract, all events, version gating, PreCompact resolution |
| 10-effort-routing-and-costs.md | Wire-verified effort routing + token/quota/cost model |
