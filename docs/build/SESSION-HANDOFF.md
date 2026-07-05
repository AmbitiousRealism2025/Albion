# Albion Session Handoff

This is the rehydration document for a new conductor session. It exists because session continuity across a restart is the exact problem Albion is built to solve — so we dogfood it. Read this top to bottom before doing anything; it plus the auto-loaded project memory (`MEMORY.md` and the files it indexes) fully rehydrate the build.

> **Reusable template.** Sections marked **[LIVE]** are updated at every session boundary. Sections marked **[STABLE]** rarely change — read them once, trust them after. To hand off, update the [LIVE] sections and commit.

---

## [LIVE] Where we are right now

**Date of handoff:** 2026-07-05 (second update this date — ALB-029 cycle). **The system is built.** M0–M5 are sealed; M6 (release engineering) is complete except the plugin-marketplace **publish**, which is externally gated on the maintainer's account. Everything below is on `main`, **28 test files** passing on macOS + ubuntu. **Push/CI caveat:** the ALB-029 commits (`41fd15f` brief, `86c6daf` implementation, plus the log-019 docs commit) may still be local — the session classifier declined the conductor's direct push to `main` pending maintainer authorization. If `git status` shows the branch ahead of origin, push and confirm CI green before building on top.
**Conductor for the next session:** Fable 5 — **but VERIFY the live model every session** (statusline shows it): Fable's safeguard silently fell back to Opus 4.8 at the M3→M4 boundary and it went unnoticed for ~15.5h; M4–M6 were actually Opus-conducted (build log 017, post-M6 audit: directionally sound, deny floor wired as the one real fix).

### Full inventory of what is built & merged (all CI-green)
- **Launcher** `bin/albion` — modes: default / `--vanilla` (bare-GLM A/B control) / `--doctor` / `--dry-run`; both auth lanes; pins `--model glm-5.2[1m]`; injects the charter (`--append-system-prompt`), the plugin (`--plugin-dir`, default mode only), and a scoped effort config (`--settings config/albion-settings.json`); exports `ALBION_ACTIVE=1` when the plugin loads.
- **Doctor** `bin/albion-doctor` — check registry (env, claude-binary, version, endpoint-shape, tmux, fixtures, hook-suite, manifest, vision, effort) + `--live` (1-token probe, verified `HTTP 200 model=glm-5.2`).
- **Enforcement layer** (`state/` engine + 6 hooks in `plugin/scripts/`): destructive-command guard, strike counter, workbench scrubber, **Stop completion gate** (keystone; writes the completion-manifest done-signal), SessionStart re-injection, image-read interception. **All 6 gate on `ALBION_ACTIVE`** (inert in stock claude). Wired in `plugin/hooks/hooks.json` (string-form commands — array-form was silently ignored, log 012). Live registration proven by `tests/tools/verify-registration.sh`.
- **Charter** `charter/ALBION.md` — compiled from `manifest/sections/` by `bin/albion-compile` (`--check` drift gate).
- **Skills** (`plugin/skills/`): maturity-assessment, delegation, recovery, completion-gate, conductor, + vendored standalone fable-mode. **Agents** (`plugin/agents/`): scout, counterexample-hunter, verifier, simplifier, quick.
- **Vision** `bin/albion-vision` — direct GLM-4.6V, both lanes, no MCP; `ALBION_VISION_TOKEN`/`ALBION_VISION_LANE` for a separate metered 4.6V key.
- **Telemetry** `telemetry/albion-metrics` (dual cost model; harness `total_cost_usd` proven ~2.7× overstated). **Bench** `bench/run-task` + `bench/report` + the task corpus under `bench/tasks/` (incl. the board-stressing `retry-idempotency` ALB-026, the hidden-holdout `grade-integrity` ALB-027, and the long-horizon `revenue-pipeline` ALB-028); first A/B report at `bench/reports/m5-first-ab-report.md`. `--vanilla` is a true-bare control (the launcher appends `--disable-slash-commands`). **Since ALB-029 the bench discriminates on process:** run records are `albion-bench-run/v2` with a `workbench` object (artifact inventory + `evidence_complete`, stop-gate-aligned), and `bench/report` adds `evidence` / `evidence_complete_rate` columns; v1 records stay ingestible (build log 019).
- **Distribution:** `install.sh` (fresh-machine, symlinks the tools), `bin/albion-setup` (interactive creds → mode-600 secrets), `bin/albion-package` (builds a **self-contained plugin** dir carrying the launcher; launcher/doctor/hooks are layout-agnostic — verified live from the packaged dist). CI is SHA-pinned + least-privilege; community files + CHANGELOG in place.
- **Docs:** README (locked, completed-tense, coexistence section, milestone trail at end), `docs/glm-5.2-setup.md`, `docs/packaging.md`, `docs/security-model.md`, `docs/build/orchestration.md`, build logs 000–016.

### >>> THE MOST IMPORTANT THING: design decisions queued for the maintainer <<<
From the **log-014** long-horizon A/B diagnostic (4 runs on a real 350k-LOC repo; reports at `~/Desktop/albion-factory-analysis/`). These are **n=1 hypotheses NOT to act on autonomously** — they were explicitly left for the maintainer:
- **(a) Re-scope or retire the workbench + SessionStart re-injection hook.** The external workbench engaged in **zero** of four long-horizon runs; the charter's convergence prevents the compaction the re-injection hook exists to survive; and when compaction *did* happen (vanilla arm), native handling preserved the findings anyway. Clean test: a **`--lite` charter A/B** (trivial via the compile pipeline — drop the workbench/loop scaffolding, keep the contract + intent gate + task-tracking).
- **(b) Keep the always-on task-tracking.** It is the *one* charter feature with a measured benefit — at max effort the charter arm converged **2.2× faster** (15 vs 33 min) because task-tracking gives GLM a definition of "done"; the skill-only arm sprawled and compacted.
- **(c) Fix the bench methodology.** The `--vanilla` control auto-loads the user-scope `fable-mode` skill (so it's *skill-only*, not bare) — disable it for a true bare arm. And build tasks that stress the **enforcement layer** (destructive actions, hidden-acceptance-gate reward-hacking, multi-session) rather than read-only analysis, which exercises none of it.

### What to do next
1. **Publish the marketplace plugin** (maintainer step): `bin/albion-package` → upload `dist/albion`. Only the publish + `/plugin install` round-trip remains untested (needs the account).
2. **Charter-trim track** (the maintainer call is made — no `--lite` product mode, trim the ONE charter; see memory `albion-design-philosophy`): phase 1 (ALB-029 process metrics, log 019) AND the first phase-2 A/B (log 020) are done. **Headline result: headless on `revenue-pipeline`, the full charter opened the board 0/3 while the 138-line lean instrument (`docs/build/experiments/lean-charter-v1/`) opened it 2/3 with evidence-complete boards — inverted from expectation; n=3, direction not significance.** Next to settle it: (a) more headless n (~3 min/run; method in log 020 — `env -i` scrub, fresh per-arm `CLAUDE_CONFIG_DIR`, `ALBION_CHARTER` override for the lean arm), (b) one interactive lean run (log-018 tmux protocol) to check lean retains interactive engagement + compaction recovery, then (c) the trim proposal goes to the maintainer with the lean composition as the candidate.
3. **M7 — hardening:** provider abstraction (data-sovereignty toggle), interactive conductor steering, lessons promotion.

### Carry-forward facts (load-bearing)
1. **Run at `xhigh`/GLM-max** — both better and faster for the charter arm (log 014). The launcher now self-enforces this via `config/albion-settings.json`, scoped to albion sessions (does NOT touch the user's global). The doctor `effort` check verifies the shipped config.
2. **Coexistence is solved:** `albion` (GLM) and `claude` (Anthropic) run side by side with zero interference. Hooks gate on `ALBION_ACTIVE` (only the launcher sets it, default mode only). Never rely on that being set elsewhere.
3. **Vision-lane verdict** (research report 11, local-only): plan tokens authorize direct GLM-4.6V via `api.z.ai/api/anthropic/v1/messages`; paas/v4 rejects plan tokens (429/1113); no MCP needed.
4. **Worker sandbox pattern:** `--permission-mode acceptEdits --allowedTools "Bash(<narrow>:*)"`, **never** `bypassPermissions` (classifier-denied). Dispatch loop unchanged (see [STABLE] below).
5. **User's Z.ai token** is at `~/.albion/secrets.zsh` (← `~/.zshenv`); the doctor `--live` works from any shell. Private long-horizon A/B reports at `~/Desktop/albion-factory-analysis/` (kept off the public repo).
6. **Standing worker-lane rule (holding since the ALB-016 gamed-counter, log 010):** every brief carries "if an out-of-scope test breaks, STOP and report"; the conductor reads *every hunk* of worker diffs and *every unit's exit code*. **CI's shellcheck is stricter than this dev machine's** — watch for SC2015 (`A && B || C`); use explicit `if`.

### Open threads / backlog (non-blocking)
- **Hook hardening** (`docs/security-model.md`, log 007): denylist runtime-obfuscation gaps are inherent — do NOT attempt heuristic fixes; relocating `gate.blocks` outside agent-writable state is possible future work.
- **peak-window `last_test` miss** (log 013): a per-run state-write gap; detection + write-path are both provably correct — needs a dedicated repro.
- **CI actions** are now SHA-pinned (checkout@v5.0.0). Further SHA-pinning of any actions added later stays a pristine-repo habit.

---

## [STABLE] How this project is built

**The methodology** (full detail in `docs/build/orchestration.md`): a frontier Claude **conductor** decomposes milestones into 7-section work packets and dispatches them to **GPT-5.5 via `codex exec`** in tmux; **GLM-5.2 never builds** (it is the test subject). The conductor reviews every diff against the brief, runs the tests itself, owns all git, and journals each cycle. The build log is deliberately honest (failures, reworks, and conductor mistakes included) because that honesty is its value for the OSS-grant story.

### The dispatch loop (mechanical steps)
1. Write the brief: `docs/build/packets/ALB-<n>.md` (7 sections), commit it.
2. Dispatch: create `.albion/handoff/ALB-<n>/dispatch.sh` (copy an existing one, `sed` the packet id), launch in a tmux session `albion-ALB-<n>`, and start a background watcher that polls `tmux has-session` and reads the `exit-code` + `last-message.md`.
3. Review: `git status` scope-check, run the full suite yourself, **probe the actual behavior directly** (do not trust the worker's self-report — the whole project's thesis is that honor-system claims are worthless), run the CI-equivalent shellcheck batch.
4. Commit (conductor owns git; co-author lines below), push, **gate acceptance on CI green** (not just the local suite).
5. Journal: `docs/build/log/<nnn>-*.md` with metrics.

### Standing rules adopted mid-build (do not relearn these the hard way)
- **Acceptance gates on CI green**, not the local suite alone. (M1 shipped a commit before CI reported and caught a platform bug the hard way — build log 004.)
- **Run the CI-equivalent shellcheck batch locally before every push** — the exact `find … | xargs -0 shellcheck` invocation from `.github/workflows/ci.yml`, not per-file `shellcheck` (single-file runs raise false SC1091s). shellcheck is installed on the dev machine.
- **Portability is enforced** (`CONVENTIONS.md`): identical behavior on macOS (BSD) and ubuntu (GNU); use `python3` for filesystem metadata/timestamps, never `stat -f`/`stat -c` fallback chains (GNU `stat -f` *succeeds with different semantics* — build log 006). Tests that depend on a binary's absence build an isolated PATH from a symlink farm (the tmux lesson — build log 004).
- **Parallel workers share one tree**: a worker running the *full* suite mid-fan-out may see another worker's half-written test file. Ignore per-worker full-suite reports during fan-out; the conductor's post-merge suite run is the real gate. (Consider worktree isolation if this gets noisy.)
- **Every brief carries explicit MUST-NOT-DO scope and forbids git state changes**; workers are sandboxed to the workspace.

### Co-authorship convention
- Conductor commits: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` (was Fable 5 through most of M2; use whatever tier the session is actually running).
- Worker-implemented commits also add: `Co-Authored-By: GPT-5.5 via Codex CLI <noreply@openai.com>`.

### Key config facts (empirically locked — see memory + research reports)
- Launcher must pin `--model glm-5.2[1m]` (the user's global settings pin a Fable model that otherwise reaches Z.ai and 400s).
- Never set `CLAUDE_CODE_EFFORT_LEVEL` (kills per-task frontmatter effort routing).
- `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` forces headless permission mode to default (breaks scripted `acceptEdits`) — env default is 0.
- Effort has three effective tiers via Z.ai: off / GLM-high / GLM-max.

### Where everything lives
| What | Path |
|---|---|
| Design proposal (v0.2) | `docs/proposal/albion-proposal.md` |
| Research analysis | `docs/research/atreides-analysis.md` |
| Build methodology | `docs/build/orchestration.md` |
| Build logs (chronological) | `docs/build/log/` |
| Work packet briefs | `docs/build/packets/` |
| Threat model | `docs/security-model.md` |
| Conventions (read before coding) | `CONVENTIONS.md` |
| Project memory (auto-loaded) | `~/.claude/projects/…/memory/` (indexed by `MEMORY.md`) |
| Shipped code | `bin/` (albion, -doctor, -vision, -compile, -setup, -package), `env/`, `charter/`, `config/`, `manifest/`, `state/`, `plugin/`, `telemetry/`, `bench/` |
| Distribution / setup docs | `docs/glm-5.2-setup.md`, `docs/packaging.md`; `install.sh` at repo root |
| Vision-lane probe (local-only) | `docs/research/reports/11-glm-4.6v-plan-lane-probe.md` |
