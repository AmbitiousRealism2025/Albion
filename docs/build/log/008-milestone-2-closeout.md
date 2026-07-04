# Build Log 008 — Milestone 2 Closeout: The Enforcement Layer

**Date:** 2026-07-04
**Milestone:** M2 — hooks + session-state engine. **Status: complete, sealed, CI-green.**

## What M2 delivers

The layer that converts fable-mode's honor-system discipline into mechanism — the core answer to the project's central finding (GLM-5.2's reward-hacking lineage makes honor-system orchestration unsafe; enforcement must be deterministic):

- **Session-state JSON engine** (`state/`): atomic, `flock`-guarded, `python3`-stdlib CLI + bash wrapper. Verified under 20-way concurrent increment.
- **Five enforcement hooks** (`plugin/scripts/`), all command-type, JSON-on-stdin, fail-open, integration-tested against **17 real captured payloads** plus synthetic fixtures:
  1. **Destructive-command guard** (PreToolUse) — normalization pipeline + deny table + `permissions-deny.json` hard floor.
  2. **Strike counter** (PostToolUse) — per-operation failure counts, factual injection at strike 2, counterexample-first guidance at 3.
  3. **Workbench secrets scrubber** (PostToolUse) — redacts a credential registry in `.agent-workbench/` writes, incl. NotebookEdit.
  4. **Stop completion gate** (Stop) — the keystone; blocks premature "done" on open tasks / failed tests / empty verification; loop-safe by a 3-block ceiling that can never trap a session.
  5. **SessionStart re-injection** — the verified compaction-survival channel.
- **Wiring + verification** (`plugin/hooks/hooks.json`, `verify-hooks.sh`): the doctor's `hook-suite` check went from stub to a real recorded-payload runner. A mutation test (neutering the guard makes the verifier FAIL) proves the check is not hollow.
- **`docs/security-model.md`**: an honest threat model — these hooks are best-effort defense-in-depth over the hard floor, not a security boundary against a determined adversary.

## The story of M2 (why it's a good chapter)

M2 was the hardest and most eventful milestone, and the process earned its keep three distinct ways:

1. **Dogfooding caught two ship-blockers before any user.** Running Albion's own capture kit through `bin/albion` (build log 005) surfaced that the user's global settings pin a model that reaches Z.ai and 400s, and that `SUBPROCESS_ENV_SCRUB=1` breaks headless `acceptEdits`. Both fixed in ALB-M1-R2.
2. **The adversarial red-team found two correctness bugs unit tests couldn't** (build log 007) — a dead NotebookEdit scrubber target and a guard normalizer that defeated itself on `\rm -rf /`. Both were failures of *imagination*, not logic, which is exactly what a red-team catches and a unit test doesn't. The triage was honest in both directions, dropping the hunters' own over-claims. Fixed in the R1 reworks, plus ~13 cheap hardening additions.
3. **CI caught what local review couldn't** — twice — both platform seams (BSD vs GNU `stat`; tmux install location). Each produced a permanent CONVENTIONS rule so the class of bug can't recur.

## Metrics

| Metric | Value |
|---|---|
| Packets accepted this milestone | 11 (6 hooks/engine + keystone + 3 red-team reworks + wiring + M1-R2) |
| Rework cycles | 3 R1 reworks (all red-team-driven correctness+hardening) + 2 CI-caught fixes |
| Genuine defects caught before merge | 2 correctness (red-team) + 2 config (dogfooding) + 2 platform (CI) |
| Defects shipped to `main` unnoticed | 0 |
| Adversarial workflow | 4 agents, ~30 evidenced attempts, ~310k Claude-side tokens |
| GPT-5.5 worker tokens (M2 packets) | ~1.42M |
| Test suite | 12 files, green on macOS + ubuntu |
| Commits on `main` | 34 |

## Conductor-model note

Most of M2 ran on Fable 5; partway through the security-tooling packets a dual-use safeguard flagged the content and the session continued on Opus 4.8 (see `orchestration.md`). The security-dense milestone was a natural fit for Opus. The reasoning- and design-heavy M3 (charter + skills) is the right place to resume on Fable.

## Next: Milestone 3

The unified `ALBION.md` operating system (fable-mode baked in), the crown-jewel skills, and the agent roster — packaged as a plugin. See `docs/build/SESSION-HANDOFF.md` for the clean starting point. The enforcement layer M3's charter points at is now real, tested, and honestly scoped.
