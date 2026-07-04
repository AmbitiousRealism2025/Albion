# Build Log 006 — The Hook Fan-Out: Four Enforcement Hooks in Parallel

**Date:** 2026-07-04
**Packets:** [ALB-007](../packets/ALB-007.md) guard · [ALB-008](../packets/ALB-008.md) strikes · [ALB-010](../packets/ALB-010.md) scrubber · [ALB-011](../packets/ALB-011.md) inject · all ACCEPTED · plus prerequisites [ALB-M1-R2](../packets/ALB-M1-R2.md), [ALB-006](../packets/ALB-006.md)

## Dispatch

Four concurrent `codex exec` workers against one shared tree, disjoint path scopes. All four completed in **420 s** — the widest fan-out of the build, and roughly the wall-clock of a single serial packet.

## The concurrency signal worth recording

Three of the four workers (008, 010, 011) independently reported that `tests/test_guard.sh` failed in *their* full-suite run with "a JSON parse on empty input." This looked like a real ALB-007 bug — three independent reports of the same failure is exactly the kind of signal the review must not dismiss.

Investigation: it was an **artifact of parallel dispatch**, not a defect. Each of those three workers ran `bash tests/run.sh` (the whole suite, per their briefs) while ALB-007's `test_guard.sh` was still mid-write in the shared tree — they observed a half-written test file. Once all four finished, the full suite passed 10/10.

**But the report was specific enough to verify rather than wave away.** The conductor probed the guard's empty-stdin and malformed-stdin paths directly: both allow cleanly (exit 0, no output), captured payloads all allow, `rm -rf /` and the `%72m`-obfuscated variant both deny. The guard is correct. Lesson logged: **parallel workers sharing a tree will observe each other's partial writes; per-worker full-suite runs are unreliable mid-fan-out — the conductor's post-merge suite run is the real gate.** (Fix forward for later: dispatch file-scoped packets in worktrees, or have workers run only their own test file.)

## A near-miss in the other direction

The conductor's own first scrubber probe used a malformed AWS test value (`AKIA` + 18 chars) and briefly read as "scrubber missed an AWS key." Re-probed with a well-formed key (`AKIAIOSFODNN7EXAMPLE`): redacted correctly, and the worker's own test already covered all 8 secret types with proper values. **Careful verification cut both ways this cycle — it cleared a worker of a bug that wasn't there, and nearly invented one that wasn't there either.** Evidence settles it; first impressions don't.

## Review gate (conductor-run, fresh evidence)

| Hook | Verified behavior |
|---|---|
| Guard (007) | 8 captured → allow; `rm -rf /`, fork bomb, pipe-to-shell, `%72m` obfuscation → structured deny; empty/malformed stdin → allow+exit 0 |
| Strikes (008) | silent at 1; "Strike 2 of 3" at 2; counterexample-first guidance at 3; success resets the counter |
| Scrubber (010) | all 8 secret types redacted in place with `[REDACTED:<type>]`; notice reports counts+types not values; workbench-scoped |
| Inject (011) | task.md + state-map + state re-injected with `source` echo under budget; empty session → silence |
| All | full suite 10/10; CI-equivalent batch shellcheck clean |

## Prerequisites this cycle (also accepted)

- **ALB-M1-R2**: env override semantics (tuning vars export-if-unset; scrub default 0) + launcher `--model glm-5.2[1m]` pin. Fixes build-log-005's two live findings.
- **ALB-006**: session-state JSON engine (20-way concurrent increment verified).

## CI reds this cycle (both conductor fix-forwards, both platform seams)

1. Unused loop variable (`SC2034`) + `state/` was outside CI's shellcheck scope.
2. GNU `stat -f` *succeeds with different semantics* rather than failing, so the worker's `stat -f || stat -c` fallback never triggered on ubuntu → mode check read a `stat` help dump. Fixed with a `python3 os.stat` mode check and a new **Portability** section in CONVENTIONS.md (inherited by all future briefs). shellcheck is now installed on the dev machine; the conductor runs the exact CI batch locally before every push, closing the asymmetry that produced both reds.

## Metrics running totals

| Metric | Value |
|---|---|
| Packets accepted | 12 (ALB-001..011 + M1-R2), 2 rework cycles total (both CI-caught platform issues) |
| Blocking defects shipped | 0 |
| Worker tokens, OpenAI lane, this cycle | 007: 140,132 · 008: 152,803 · 010: 71,953 · 011: 74,000 (+ M1-R2, 006 earlier) |

## Next

- **ALB-009** — Stop completion gate (the keystone hook: blocks premature "done" on open tasks / failed tests / empty verification.md). Dispatched with the state-key conventions ALB-006/008 established.
- **ALB-012** — wire all six hooks into `plugin/hooks/hooks.json`, replace the doctor's hook-suite stub with a real recorded-payload runner, closing Milestone 2.
