# Albion Session Handoff

This is the rehydration document for a new conductor session. It exists because session continuity across a restart is the exact problem Albion is built to solve — so we dogfood it. Read this top to bottom before doing anything; it plus the auto-loaded project memory (`MEMORY.md` and the files it indexes) fully rehydrate the build.

> **Reusable template.** Sections marked **[LIVE]** are updated at every session boundary. Sections marked **[STABLE]** rarely change — read them once, trust them after. To hand off, update the [LIVE] sections and commit.

---

## [LIVE] Where we are right now

**Date of handoff:** 2026-07-05 (M3–M5 sealed, M6 substantially complete — all one session)
**Milestone complete:** **M6 — substantially complete** (build log 015): `install.sh` fresh-machine installer, hook-registration smoke-check (`tests/tools/verify-registration.sh`, live-PASS — closes the inert-hooks class), effort-default fix (doctor `effort` check), CI SHA-pinned + least-privilege, community files + CHANGELOG. Remaining M6 step = the plugin-marketplace **publish** itself (externally gated, needs maintainer account). Suite = 28 files green. **Coexistence + self-containment done (build log 016):** every hook gates on ALBION_ACTIVE (inert in stock claude even if globally enabled); effort scoped to albion sessions via --settings; `bin/albion-setup` (interactive creds); `ALBION_VISION_TOKEN`/`ALBION_VISION_LANE` (separate 4.6V key); `bin/albion-package` builds a single self-contained plugin dir carrying the launcher (launcher/doctor/hooks are layout-agnostic) — verified live: a session from the packaged dist registers+fires hooks. `docs/glm-5.2-setup.md` + `docs/packaging.md` written; README locked (completed-tense, coexistence section, milestone table moved to end).
**THE IMPORTANT THING — design decisions queued for the maintainer** (from the log-014 long-horizon A/B diagnostic; NOT decided autonomously): (a) **re-scope/retire the workbench + SessionStart re-injection hook** — four long-horizon runs, zero workbench engagement; charter convergence prevents the compaction the re-injection hook exists to survive; a `--lite` charter A/B is the clean test. (b) **Keep the always-on task-tracking** — the one charter feature with a measured benefit (2.2× convergence at max effort). (c) **Fix the bench:** `--vanilla` is contaminated by the user-scope `fable-mode` skill (disable it for a true bare arm); build tasks that stress the enforcement layer, not read-only analysis. All log-014 findings are n=1 hypotheses awaiting repeated trials.
**Next milestone:** **M7 — hardening** (provider abstraction, interactive conductor steering) — but the charter-design conversation above should happen first.
**Conductor for the next session should be:** Fable 5.
**Carry-forward facts:** (1) **Run at `xhigh`/GLM-max** — it is both better and faster for the charter arm (log 014); the doctor now warns if effortLevel isn't xhigh. (2) **Vision-lane verdict** (research report 11, local): plan tokens authorize direct GLM-4.6V via `api.z.ai/api/anthropic/v1/messages`; paas/v4 rejects plan tokens (429/1113); no MCP needed. (3) Worker sandbox pattern: `--permission-mode acceptEdits --allowedTools "Bash(<narrow>:*)"`, never bypassPermissions. (4) User key at `~/.albion/secrets.zsh` ← `~/.zshenv`. (5) Long-horizon A/B reports for a private repo kept off-repo at `~/Desktop/albion-factory-analysis/`.

### What is done and merged (all CI-green, on `main`)
- **M0** research + proposal (v0.2), including live wire-probes against the Z.ai endpoint.
- **M1** launcher + doctor: `bin/albion` (default/`--vanilla`/`--doctor`/`--dry-run`, both auth lanes, `--model glm-5.2[1m]` pin), `bin/albion-doctor` (check registry + `--live` probe, verified `HTTP 200 model=glm-5.2`), `env/albion-env.sh`.
- **M2** enforcement layer: session-state JSON engine (`state/`), six hooks in `plugin/scripts/` — destructive-command guard, strike counter, workbench scrubber, Stop completion gate (keystone), SessionStart re-injection — all hardened after an adversarial red-team (build log 007), wired in `plugin/hooks/hooks.json`, verified by the doctor's `hook-suite` check. `docs/security-model.md` states the honest threat model.
- **M3** behavioral layer: `charter/ALBION.md` (conductor-written, maintainer-approved, compiled from `manifest/sections/` by `bin/albion-compile` with a `--check` drift gate), four crown-jewel skills + vendored fable-mode skill (`plugin/skills/`), five agents (`plugin/agents/`), `plugin.json`, launcher `--plugin-dir` wiring (default mode only), doctor `manifest` check. Workbench layout everywhere is the per-task-directory form the hooks enforce (`.agent-workbench/fable-mode/<task-slug>/`).
- Test suite: zero-dependency, 16 files, green on macOS **and** ubuntu; CI (shellcheck + tests) on every push.

### What to do next (first steps)
1. **Run the M3 exit test** (needs the user-held Z.ai token): launch `bin/albion` on a scratch long-horizon task; verify the full loop end-to-end — workbench task dir with populated `task.md`/`verification.md`, hook injections, stop gate honest, report in charter §8 form. Then seal M3 in a short log entry.
2. **M4 packet breakdown** per proposal §6 (vision: provider registry, `albion-vision`, image-read hook) and §7 (Conductor skill + completion-manifest protocol). Get maintainer approval on the packet plan before dispatching.

### Open threads / backlog
- **Hook hardening backlog** (documented, non-blocking) in `docs/security-model.md` and build log 007: runtime-obfuscation gaps are inherent to denylists (do not attempt heuristic fixes); relocating `gate.blocks` outside agent-writable state is possible future work.
- **Hook registration smoke-check** (from log 012): nothing tests that Claude Code actually *loads* the plugin hooks — add one cheap headless session with a marker hook so the inert-hooks class can't silently regress.
- **Bench corpus is too easy** (log 013): both arms solve 6/6; the corpus can't yet discriminate the arms. The single most valuable next step for proving Albion's thesis is long-horizon / multi-file / unclear-cause tasks that exercise the workbench tier (which has *never* engaged solo across M3–M5).
- **peak-window `last_test` miss** (log 013): a per-run state-write gap needing a dedicated repro; detection and write-path are both provably correct.
- **CI actions are major-version-pinned**; SHA-pinning + the `actions/checkout@v4` Node-20 deprecation are M6 tasks.
- **Worker-lane trust note (build log 010):** standing brief boilerplate "if an out-of-scope test breaks, STOP and report" is holding (record intact since ALB-016). Conductor must read *every hunk* of worker diffs and *every unit's exit code* (log 013's non-exec-setup catch).

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
| Shipped code | `bin/`, `env/`, `state/`, `plugin/` |
