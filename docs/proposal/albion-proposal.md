# Albion: Proposal for a GLM-5.2 Orchestration System Built Around Fable-Mode

**Version:** 0.2 (proposal for review)
**Date:** 2026-07-04
**Basis:** [Deep research analysis](../research/atreides-analysis.md) — 11-agent research mission over the Atreides repo, DeepWiki, the fable-mode-glm-5-2 skill, GLM-5.2's live documentation, and wire-level probes against the Z.ai endpoint.
**Companion:** [Visual companion (HTML)](albion-companion.html)

**Changes in v0.2** (post-review direction from the maintainer): fable-mode is now **baked into a unified ALBION.md** rather than gated behind skill invocation; a **pluggable vision subsystem** is added; a **Conductor** skill (stock Claude Code ↔ Albion orchestration over tmux) is promoted to a first-class deliverable; the project is **MIT open-source** with a pristine-repo/OSS milestone; both **Z.ai API and Coding Plan** auth lanes are supported; portability to Opencode ("Oakdale") and Pi ("Bower Lake") becomes a standing design constraint. Additionally, the **build process is itself orchestrated and documented** (§9.1): a Claude (Fable 5) conductor dispatching work packets to GPT-5.5 via `codex exec`, journaled in [`docs/build/`](../build/orchestration.md).

---

## 0. Thesis

Albion is the deliberate combination of three things that already exist but have never been joined:

1. **A working GLM-5.2 Claude Code environment** — Z.ai's Anthropic-compatible endpoint, opus-slot→glm-5.2 mapping, 1M context.
2. **The fable-mode-glm-5-2 skill** — an evidence-first operating discipline that counters GLM-5.2's exact documented failure modes (long-horizon drift, ungrounded progress claims, premature convergence).
3. **Atreides' model-agnostic orchestration IP** — intent gating, maturity assessment, delegation templates, exploration termination, completion gates — *stripped of its persona theater, its broken hook layer, and its Anthropic-coupled model routing.*

The organizing principle, dictated by the research: **GLM-5.2 inverts the enforcement equation.** Claude tolerated honor-system orchestration; GLM-5.2 (SWE-Marathon 13.0 vs Opus 4.8's 26.0, reward-hacking lineage, drift under long horizons) requires that every rule that *can* be enforced deterministically *is* enforced deterministically, and that everything left in the prompt is radically compressed.

### The product goal

**Give people who like Claude Code a lower-cost option that does not sacrifice too much.** Albion must be a complete, strong system **standing alone** — the Conductor, vision, and frontier lanes are amplifiers, never dependencies. Success is a solo `albion` session being the best GLM-5.2 coding experience available.

### The four layers

| Layer | Owns | Never does |
|---|---|---|
| **ALBION.md** (unified operating system: charter + fable-mode baked in, one voice) | Routing & reasoning discipline: intent gate, phase loop, workbench discipline, evidence rules, communication style | Restating native harness behavior; enforcement; API configuration |
| **On-demand skills & agents** | Crown-jewel procedures (maturity, delegation, recovery, completion reference), vision, conductor; scout/hunter/verifier/simplifier/quick agents | Duplicating ALBION.md content |
| **Hook suite** | Enforcement: strike counting, completion blocking, destructive-command guard, secrets scrubbing, state re-injection, image-read interception | Semantic judgment (hooks are deterministic and blind) |
| **Launcher** | Configuration: endpoint, auth lane (API/plan), model slots, effort defaults, cache hygiene, startup validation | Behavior; setting `CLAUDE_CODE_EFFORT_LEVEL` (kills per-task routing) |

Every rule lives in **exactly one layer** — duplication across layers is the documented Atreides drift pathology.

---

## 1. Repository & Deliverable Layout

```
albion/
├── LICENSE                       # MIT
├── bin/
│   ├── albion                    # launcher (sources env, validates, execs claude)
│   ├── albion-doctor             # health/contract verification CLI
│   └── albion-vision             # one-shot vision helper (image + prompt → text)
├── env/
│   └── albion-env.sh             # GLM environment (API-key and Coding-Plan lanes)
├── plugin/                       # the "albion" Claude Code plugin
│   ├── .claude-plugin/plugin.json
│   ├── skills/
│   │   ├── fable-mode-glm-5-2/   # standalone skill (for stock-CC users; content is
│   │   │                         #   also baked into ALBION.md for Albion sessions)
│   │   ├── maturity-assessment/
│   │   ├── delegation/
│   │   ├── recovery/
│   │   ├── completion-gate/
│   │   ├── vision/               # vision subsystem front-end (§6)
│   │   └── conductor/            # cross-session orchestration (§7)
│   ├── agents/
│   │   ├── scout.md              # read-only explorer (effort: high)
│   │   ├── counterexample-hunter.md
│   │   ├── verifier.md           # fresh-context verification (effort: xhigh)
│   │   ├── simplifier.md
│   │   └── quick.md              # trivial tier (model: haiku → glm-5-turbo, thinking off)
│   ├── hooks/hooks.json
│   └── scripts/                  # hook implementations (jq over stdin JSON)
├── charter/
│   └── ALBION.md                 # the unified operating system (~550–650 lines)
├── manifest/
│   └── albion-manifest.yaml      # single source of truth; targets: claude-code
│                                 #   (future: oakdale/opencode, bower-lake/pi)
├── state/                        # session-state JSON engine (schema + helpers)
├── telemetry/                    # per-task metrics; dual cost model (tokens vs prompts)
├── bench/                        # regression benchmark (per model/provider bump)
├── .github/                      # CI, issue/PR templates, CONTRIBUTING, SECURITY
└── docs/
```

**Distribution:** plugin-marketplace entry (commit-SHA pinned) + one-command installer that works on a **fresh machine** — no assumptions about pre-existing GLM setups. `albion doctor` diffs installed assets against the version manifest.

**Note on fable-mode as a standalone skill:** the skill keeps shipping as an independently usable artifact — stock Claude Code users (any backing model) can adopt just the skill. This is deliberate OSS surface area: the skill is the gateway drug; Albion is the full system.

---

## 2. Layer 4 — The Launcher (`albion`)

### 2.1 Auth lanes: Coding Plan and API key (both first-class)

Both lanes hit the same `https://api.z.ai/api/anthropic` endpoint with different tokens and different economics:

| | Coding Plan | API key |
|---|---|---|
| Metering | **Prompts** per 5h window (~15–20 model calls each); 3× at peak (14:00–18:00 UTC+8) | **Tokens** ($1.40/M in, $0.26/M cached, $4.40/M out) |
| Best for | Daily-driver usage (Lite $18/mo ≈ 9–25 medium tasks/window) | Overflow, CI, bursty fan-out |
| Telemetry must report | Prompt-equivalents consumed (calls ÷ ~18, × peak multiplier) | Token cost from `usage`/`modelUsage` |

`albion-env.sh` reads `ALBION_AUTH_LANE=plan|api` (+ the corresponding token env var), and telemetry reports the correct cost model for the active lane. Claude Code's own `total_cost_usd` is ignored (verified wrong under Z.ai).

### 2.2 Environment (verified values)

```bash
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"   # never /api/paas/v4
export ANTHROPIC_AUTH_TOKEN="${ALBION_ZAI_TOKEN:?set ALBION_ZAI_TOKEN}"

# [1m] suffix REQUIRED to unlock 1M context (client-side convention)
export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2[1m]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5-turbo"           # the only genuinely different tier

export API_TIMEOUT_MS=3000000
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=131072

# Cache hygiene (cached input $0.26/M; the ~17k-token tool JSON is the largest cacheable asset)
export CLAUDE_CODE_ATTRIBUTION_HEADER=0
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1
export CLAUDE_CODE_STOP_HOOK_BLOCK_CAP=4

# NEVER set CLAUDE_CODE_EFFORT_LEVEL (overrides frontmatter; collapses per-task routing).
# Session default effort comes from settings.json "effortLevel": "xhigh".
```

### 2.3 Modes

| Command | Purpose |
|---|---|
| `albion` | The product: GLM-5.2 + ALBION.md + plugin |
| `albion --vanilla` | GLM-5.2 bare — the A/B control arm |
| `albion --doctor` | Full health matrix; non-zero exit on any red cell |
| `claude` | Untouched stock Claude Code (baseline / conductor host) |

### 2.4 Startup validation (fails loudly)

Endpoint is `/api/anthropic`; a 1-token probe returns model `glm-5.2` (catches silent slot remapping); Claude Code ≥ 2.1.163 (warn < 2.1.195); auth lane configured; every hook answers a synthetic stdin payload correctly.

---

## 3. Layer 1 — ALBION.md: The Unified Operating System

**The v0.2 structural decision: fable-mode is baked in, not gated.** Merging the charter and the skill into one always-on document with one voice dissolves the trigger-authority tension entirely (the 0/3 auto-trigger problem stops mattering — there is nothing to trigger), eliminates two-document drift (the Atreides pathology), and costs ~2.2k always-on tokens (~$0.0006/turn cached; quota-free on the plan).

**Target: ~550–650 lines**, structured for GLM-5.2's instruction-following profile:

1. **Identity + activation contract (top).** One identity line, then fable-mode's 6-rule contract verbatim — autonomy on reversible actions, pause on destructive/scope/secrets, analysis-means-no-fix, no scope creep, **no unevidenced progress claims**, no raw reasoning exposure.
2. **The intent gate (routing table).** Simplified from v0.1 — it no longer decides skill invocation, only *depth and delegation*:

   | Intent | Route | Workbench |
   |---|---|---|
   | Trivial | Answer directly or `quick` agent (thinking-off tier) | No files (the contract's own scaling rule) |
   | Explicit | Direct staged execution | Minimal (task.md only if multi-file) |
   | Exploratory | Parallel `scout` agents | scout summaries feed state-map.md |
   | Open-ended / long-horizon | Full operating loop + workbench + verification agents | Full, hook-scaffolded |
   | Ambiguous | One clarifying question, reclassify | — |

3. **The operating loop.** Scope Lock → State Map → Hypotheses → Staged Execution → Independent Verification → Report — fable-mode's full procedure, including boundary probes, danger-lantern names, counterexample-first recovery.
4. **Workbench specification** (compact) + task-tracking rule (TaskCreate/TaskUpdate — GLM never self-initiates tracking; verified).
5. **Delegation pointer** (7-section template lives in the `delegation` skill) + guard rails.
6. **Communication style + stop rule.**
7. **Re-anchor line (bottom).** A one-line restatement of the contract — the top-and-bottom duplication is an empirically motivated adherence hack, kept in minimal form.

**GLM-specific writing style throughout:** terse imperatives, tables over prose, current tool names, no persona repetition, factual (not exhortative) phrasing.

### The inverted effort model

With fable-mode always-on, effort control inverts relative to v0.1 — simpler and stronger:

- **Session default: `effortLevel: xhigh`** in settings.json → GLM `reasoning_effort: max` (Z.ai's own recommendation for coding). The main agent always reasons at full depth.
- **Downshift via delegation:** `quick` (haiku slot, thinking-off) for trivial work; `scout`/`simplifier` at `effort: high` for volume exploration. Wire-verified: agent frontmatter reaches the API per-task.
- Three effective tiers remain (off / high / max); routing happens only at task boundaries (cache-safe).

**What stays a hypothesis:** the compliance-vs-coverage curve. ~600 always-on lines is a bet; the bench A/Bs it (`albion` vs `albion --vanilla`), and the manifest structure makes shrinking or growing the document a compile-time decision, not a rewrite.

---

## 4. Layer 2 — On-Demand Skills & the Agent Roster

Crown-jewel skills (unchanged from v0.1): `maturity-assessment`, `delegation`, `recovery`, `completion-gate` — compact, loaded on demand, compiled from the manifest.

| Agent | Frontmatter | Contract |
|---|---|---|
| `scout` | effort: high, read-only tools | Question / Key Findings / Patterns / Recommendations, ≤500 words, termination criteria built in |
| `counterexample-hunter` | effort: xhigh | Break the current hypothesis; failing case or "no break found" + what was tried |
| `verifier` | effort: xhigh | Fresh-context review vs task.md + tests; never sees the implementation transcript |
| `simplifier` | effort: high, read-only | Scope drift + unnecessary abstraction vs task.md |
| `quick` | model: haiku (→ glm-5-turbo) | Trivial tier; thinking auto-off; cheapest by price and quota |

Delegation economics: GLM-5.2 at 3.6–5.7× below Opus pricing means Albion is *more* aggressive with parallel scouts than Atreides' cost math ever allowed.

---

## 5. Layer 3 — The Hook Enforcement Suite

Six hooks (v0.1's five, plus image-read interception), all command-type, exec-form, JSON-on-stdin, integration-tested with recorded real payloads. Minimum Claude Code 2.1.163.

1. **Destructive-command guard** (PreToolUse) — `permissionDecision: deny` (works even in bypassPermissions); Atreides' normalization pipeline ported verbatim and finally wired in; modern-syntax permissions deny-list as the hard floor.
2. **Strike counter** (PostToolUse) — per-operation failure counts in session-state JSON; injects "Strike 2 of 3" as factual context; strike 3 → counterexample-first recovery, git-revert demoted to escalation.
3. **Completion gate** (Stop) — blocks "done" while tasks are open, the last test failed, or verification.md is empty on workbench tasks; loop-guarded, capped (4); reads `last_assistant_message` for evidence-free-claim heuristics. Aimed squarely at GLM's reward-hacking lineage.
4. **Secrets scrubber** (PostToolUse on `.agent-workbench/**` writes) — `updatedToolOutput` redaction; fable-mode's advisory note becomes mechanical.
5. **State re-injection** (SessionStart, matchers `startup|resume|clear|compact`) — the verified compaction-survival channel; re-injects task.md + state-map.md + strike/task state, each under the 10k-char cap.
6. **Image-read interception** (PreToolUse on Read of image files) — routes to the vision subsystem (§6) and returns the description via `updatedToolOutput`/`updatedInput`, so GLM-5.2 never receives raw image content it may mishandle. Degrades gracefully: with no vision provider configured, it injects a factual "no vision provider available" note instead.

**Anti-inert discipline:** every hook ships with recorded-payload tests; `albion doctor` re-runs them against the installed hooks; CI runs them on every commit. (Atreides had 466 tests and zero against the wire format.)

---

## 6. The Vision Subsystem

GLM-5.2 is powerful but not a vision model. Albion treats vision as a **pluggable capability with multiple provider options** — more options makes the project more appealing, even where that means orchestrating out to external platforms.

### 6.1 Provider registry (config-driven)

```toml
# .albion/config.toml
[vision]
provider = "zai-glm-4.6v"        # default: same Z.ai key, zero extra setup

[vision.providers.zai-glm-4.6v]  # Z.ai native API, one vendor one bill
[vision.providers.anthropic]     # ANTHROPIC_API_KEY → Claude (also the conductor host)
[vision.providers.gemini]        # GEMINI_API_KEY
[vision.providers.openai]        # OPENAI_API_KEY
[vision.providers.external]      # orchestrate out: dispatch to a vision-capable
                                 # agent session via the Conductor protocol (§7)
```

### 6.2 Three integration levels

| Level | Mechanism | Covers |
|---|---|---|
| **Helper CLI** | `albion-vision <image> <prompt>` — one-shot API call, returns text | Scripted checks, hooks, agents |
| **Transparent interception** | The image-read hook (§5.6) — GLM "reads" images through borrowed eyes, no skill invocation needed | Screenshots, design references encountered mid-task |
| **Interactive vision session** | Conductor-dispatched vision-capable agent (e.g., stock Claude Code) for multi-turn visual work | Iterative UI review, browsing screenshot sequences |

Design rules: one-shot beats screen-scraping for single Q&A; provider choice is per-project config; every level degrades gracefully when unconfigured; provider variance is a documented caveat, not a hidden one.

---

## 7. The Conductor: Cross-Session Orchestration over tmux

A skill that works **in both stock Claude Code and Albion**, enabling a Fable-driven Claude Code session to orchestrate GLM-backed Albion workers — and Albion→Albion fan-out.

**Standalone-first principle (explicit):** Albion never requires the Conductor. It is an amplifier for people who have both subscriptions; the solo `albion` experience is the product.

### 7.1 The economics

Fable does architecture, judgment, and review — its strengths, at frontier prices, used sparingly. GLM-5.2 does volume implementation at ~1/5 the cost — its strength, used liberally. This matches the community consensus ("GLM covers ~90% of routine agentic coding, lags on novel architecture").

### 7.2 The protocol: tmux for transport, files for signaling

Screen-scraping `capture-pane` for completion detection is the fragile design. Albion's protocol is file-based — **the fable workbench is the wire format**:

1. Conductor writes `task.md` (7-section delegation template) into a namespaced workbench.
2. Conductor spawns: `tmux new-session -d -s albion-w1 'albion --task <workbench-path>'`.
3. Worker runs the fable loop; the **Stop-gate hook writes a completion manifest** (JSON: status, evidence pointers, files changed) when — and only when — the gate passes. The enforcement layer doubles as the completion signal.
4. Conductor polls the manifest (cheap, deterministic), then reads `verification.md`/`evidence.md` for the report.
5. tmux stays **attachable** — the human can watch any worker live — but nothing parses the screen.

**Baseline: fire-and-forget dispatch with review-on-completion.** Interactive steering (send-keys into a worker) ships later as an opt-in extension; the file protocol doesn't change.

### 7.3 Why this design compounds

- Dissolves the session-level model-binding tension: cross-model orchestration happens at the process level, where it belongs.
- Harness-neutral: the file protocol has no Claude Code dependencies — it becomes the common bus for the Oakdale/Bower Lake ports (§10).
- Same protocol serves the vision `external` provider and the optional frontier review lane.

---

## 8. State, Memory & Telemetry

Unchanged in substance from v0.1:

- **Workbench** (model-written prose) + **session-state JSON** (hook-written); JSON wins on disagreement; workbench namespaced per task, gitignored, hook-scaffolded, archived on completion.
- Memory = workbench `lessons/` + native CLAUDE.md hierarchy + path-scoped rules. No undeclared service chains. Auto-memory off initially.
- **Telemetry** (from M2): ungrounded-claim count, scope-drift flags, counterexamples discovered, strikes, time-to-first-useful-patch, tokens by model — reported against the **active auth lane's cost model** (prompt-equivalents on plan, dollars on API).
- **Bench**: representative tasks with ground-truth checks; runs per model bump, per provider, and as the `albion` vs `albion --vanilla` A/B — finally answering fable-mode's open validation question.

---

## 9. Open Source & the Pristine Repo (MIT)

The project's goal is adoption: people using it, forking it, and building on it. That makes packaging a first-class workstream, not an afterthought — and it must meet the bar for OSS-grant program submissions (e.g., OpenAI's OSS maintainer program).

**Repo standards:**
- `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue/PR templates.
- **CI that runs the recorded-payload hook tests** on every commit — "our enforcement layer is wire-tested" is the project's credibility story and the exact discipline Atreides lacked.
- Semver releases with changelogs; commit-SHA-pinned plugin distribution.
- README with architecture diagram, honest benchmark framing, and a **fresh-machine quickstart** (no assumptions of pre-existing GLM setups).
- Raw research reports stay out of the public repo (machine-specific details); the synthesis analysis is the public research artifact.

**Disclosure obligations (prominent, not buried):**
- Data sovereignty: Z.ai first-party serving routes prompts/code through Chinese servers; the provider abstraction and its quantization-quality caveats are documented up front.
- Cost honesty: Claude Code's cost display is wrong under Z.ai; Albion's telemetry is the source of truth.

**Positioning:** multi-model, multi-harness orchestration infrastructure — not a single-vendor wrapper. The Oakdale/Bower Lake roadmap and the model-agnostic manifest make that claim concrete.

### 9.1 Built in the open, by orchestration

The build process is itself a deliverable: Albion is implemented by the same topology it ships — a frontier conductor (Claude, Fable 5) decomposing milestones into 7-section work packets and dispatching them to **GPT-5.5 (high reasoning) via `codex exec`** in tmux, with file-based completion signaling, mechanical acceptance tests, and conductor diff-review before every merge. GLM-5.2 is deliberately excluded from building — it is the test subject, and building with it would confound the project's own experiments.

The methodology and an honestly-metered build log (packets dispatched, first-pass acceptance rate, review findings, rework cycles, cost per lane — failures included) live in [`docs/build/`](../build/orchestration.md). This serves three audiences at once: OSS-grant reviewers at OpenAI (genuine, measured Codex/GPT-5.5 usage) and Anthropic (a working demonstration of Claude as a cross-vendor orchestrator), and the community (a reusable, documented pattern for running a frontier conductor over heterogeneous coding CLIs).

---

## 10. Portability Constraint: Oakdale (Opencode) & Bower Lake (Pi)

A standing **design constraint** now, a workstream later:

- The **manifest** (`albion-manifest.yaml`) gains a `target` dimension from day one: behavioral content (contract, loop, delegation template, rubric) is harness-agnostic; compile targets emit Claude Code plugin format now, Opencode and Pi formats later.
- **Hook logic lives in portable scripts** (JSON on stdin → JSON/exit codes out); only thin per-harness adapters are non-portable.
- **The Conductor file protocol is the common bus** — an Oakdale or Bower Lake worker that honors the workbench + completion-manifest contract is orchestratable by the same conductor on day one.

What we do *not* do yet: build any Opencode/Pi adapter code.

---

## 11. Roadmap (v0.2)

| Milestone | Deliverable | Exit criteria |
|---|---|---|
| **M0 — Verification** *(largely complete)* | Feature matrix under Z.ai | Remaining: cache-keying on effort; subagent prompt-accounting; Coding-Plan-lane probe parity |
| **M1 — Launcher + doctor** | `albion` / `--vanilla` / `--doctor`; both auth lanes | Doctor green on a fresh machine; loud failures on wrong endpoint/model/version |
| **M2 — Hooks + state engine** | Six hooks + session-state + recorded-payload suite | Stop gate blocks a fake "done"; strike counter injects at 2; scrubber redacts a planted secret; image hook degrades gracefully |
| **M3 — ALBION.md + skills + agents (plugin)** | Unified ~600-line operating system; crown-jewel skills; 5 agents; manifest→compile pipeline | Long-horizon task runs the full loop end-to-end solo; fable-mode also usable standalone in stock CC |
| **M4 — Vision + Conductor** | Provider registry, `albion-vision`, image hook; conductor skill + completion-manifest protocol | Fable-CC session dispatches an Albion worker and reviews its manifest; image read transparently described via GLM-4.6V |
| **M5 — Telemetry + bench** *(continuous from M2)* | Dual-cost-model telemetry; three-arm A/B; regression bench | First A/B report: albion vs vanilla-GLM on 8–12 tasks |
| **M6 — OSS release 1.0** | Pristine repo: CI, community files, quickstart, disclosures, semver release | Fresh-machine install ≤5 minutes; CI green; grant-submission-ready |
| **M7 — Hardening** | Provider abstraction (data-sovereignty toggle), interactive conductor steering, lessons promotion | Bench green across ≥2 providers or documented variance |

---

## 12. Risks & Open Questions

1. **Charter-size hypothesis** — ~600 always-on lines vs GLM's compliance curve; benched via A/B, adjustable at compile time.
2. **Always-on discipline on trivial turns** — the contract's internal scaling rule ("no extra files for simple tasks") carries this; watch for over-ceremony in telemetry.
3. **Z.ai ground movement** — silent slot remapping, bimonthly model bumps, promo-dependent pricing; doctor probe + bench per bump.
4. **Plan-lane accounting ambiguity** — whether subagent spawns/Stop-hook turns draw prompt quota is undocumented; assume call-budget draw-down until measured.
5. **Conductor fragility surface** — mitigated by file-based signaling (no screen-scraping) and fire-and-forget baseline; interactive steering deferred.
6. **Vision provider variance** — different describers give different answers; provider is explicit per-project config, never silent.
7. **Hook semantic blindness** — honesty stays a prompt rule; gates check state; the verifier agent is the semantic layer.
8. **Data sovereignty** — surfaced per-project via the provider toggle and documented prominently.

---

## 13. What Success Looks Like

- **Standalone strength:** a solo `albion` session is the best GLM-5.2 coding experience available — ungrounded-claim and premature-completion rates near zero on instrumented tasks.
- **The price claim holds:** medium tasks effectively free on Lite quota that would cost $5–15 at frontier API prices, without sacrificing "too much" — and the bench quantifies exactly how much "too much" is.
- **Adoption:** forks, plugin installs, standalone fable-mode adoption, and contributors who arrive via the pristine repo.
- **The experiment answered:** the first real data on whether fable-mode measurably improves GLM-5.2's long-horizon discipline.

---

*v0.2 prepared 2026-07-04 following maintainer review. Next step: planning — Milestone 1 breakdown.*
