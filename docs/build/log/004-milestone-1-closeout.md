# Build Log 004 — Milestone 1 Closeout: Launcher + Doctor

**Date:** 2026-07-04
**Packets this entry:** [ALB-003](../packets/ALB-003.md) (launcher), [ALB-004](../packets/ALB-004.md) (doctor), [ALB-004-R1](../packets/ALB-004-R1.md) (rework) · all ACCEPTED

## Milestone 1 exit criteria — met

- `bin/albion` launches with default / `--vanilla` / `--doctor` / `--dry-run` modes, both auth lanes, masked configuration output, distinct failure exit codes. Conductor probed every mode and error path directly; zero token leakage under a planted-secret grep.
- `bin/albion-doctor` runs a check registry (env, claude binary + version gates, endpoint shape, tmux, fixtures, M2-ready hook-suite stub) with an opt-in live probe. **On the development machine: offline all-green, and `--live` returned `HTTP 200 model=glm-5.2` against the real Z.ai endpoint with real credentials** — the silent-remap check from the research, now enforced by running code.
- CI green on the final state of all M1 code.

## The first red CI run — and what it taught

ALB-004's test suite passed on macOS and **failed on ubuntu** (run 28712025731): scenarios budgeted a tmux-absence WARN, but the stubbed PATH still exposed system directories, and ubuntu keeps tmux in `/usr/bin`. The platform difference was invisible to both the worker and the conductor's local review — only CI could catch it, which is exactly why no worker being able to run CI's environment locally makes the pipeline the arbiter, not a formality.

Rework ALB-004-R1 (195 s) rebuilt the scenarios on a private symlink farm of resolved host tools with no system dirs on PATH, covering both tmux branches explicitly and *proving* isolation by flipping the outcome with a farm-local stub. No assertions weakened. CI green.

**Process corrections adopted (conductor errors, logged with the same candor as worker ones):**
1. ALB-004 was committed after local verification but before CI reported. New rule: **acceptance gates on CI green**, not just the local suite.
2. A conductor review probe earlier in the milestone misread bash `source` prefix-assignment semantics as a worker bug (log 003). Reviews are fallible; evidence settles disputes.

## Milestone metrics (final)

| Metric | Value |
|---|---|
| Packets dispatched | 6 (5 planned + 1 rework) |
| Accepted first-pass | 5 of 5 planned briefs; 1 rework cycle (CI-caught, platform isolation) |
| Blocking review findings by conductor | 0 (the one defect was CI-caught, not review-caught — noted honestly) |
| Worker tokens, OpenAI lane | ALB-001: 87,638 · ALB-002: 106,197 · ALB-003: 113,521 · ALB-004: 143,065 · ALB-004-R1: 135,833 · ALB-005: 128,332 · smoke: 19,235 · **total 733,821** |
| Wall-clock per packet | 3–9.5 min; parallel dispatch (ALB-002+005) completed both in 285 s |
| CI runs | 5 green, 1 red (the catch) |

## State of the tree

`bin/albion`, `bin/albion-doctor`, `env/albion-env.sh`, hook-payload capture kit + synthetic fixtures, zero-dependency test suite (5 files, all green on macOS and ubuntu), CI on every push.

## Next: Milestone 2 — the hook enforcement suite

Six hooks against the verified contract (destructive-command guard, strike counter, completion gate, secrets scrubber, state re-injection, image-read interception), the session-state JSON engine, and recorded-payload tests — the layer that converts fable-mode's honor system into mechanism. First conductor task: run a real capture session with the ALB-005 kit so M2 tests run against captured payloads, not just synthetic ones.
