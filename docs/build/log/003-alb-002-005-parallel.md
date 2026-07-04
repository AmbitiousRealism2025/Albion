# Build Log 003 — ALB-002 (env) & ALB-005 (capture kit): First Parallel Dispatch

**Date:** 2026-07-04
**Packets:** [ALB-002](../packets/ALB-002.md), [ALB-005](../packets/ALB-005.md) · **Verdicts: both ACCEPTED, first-pass**

## Dispatch

- Two concurrent `codex exec` workers (gpt-5.5 high), same working tree, disjoint path scopes; tmux sessions `albion-ALB-002` / `albion-ALB-005`.
- Wall-clock: both complete in **285 s** — parallel dispatch roughly halves milestone wall-clock vs serial.
- Notable: each worker *noticed the other's concurrent untracked files, correctly identified them as out-of-scope, and left them untouched* — the MUST-NOT-DO scope guards held under concurrency without any locking mechanism.

## Review gate (conductor-run, fresh evidence)

| Check | ALB-002 | ALB-005 |
|---|---|---|
| Scope | Clean (env/ + tests/test_env.sh) | Clean (tests/ only) |
| Full suite `tests/run.sh` | PASS (3/3) | PASS (3/3) |
| Direct behavior probes | All failure paths return 1 with variable-naming messages; both lanes verified; override + double-source verified; no token leakage | Capture compacts valid JSON, quarantines malformed input at exit 0; validator passes synthetic set, fails broken fixture |
| CI on push | **SUCCESS**, 16 s (run 28711589600) | same run |

## Review findings

- **False alarm, resolved:** conductor's first api-lane probe showed `ALBION_AUTH_LANE` unset after sourcing — traced to bash's prefix-assignment-on-`source` semantics in the *probe*, not the script. Re-probed with proper exports: correct. Recorded because honest reviews include reviewer mistakes.
- **Non-blocking (ALB-005):** the settings snippet's relative script path won't resolve from a scratch project as-is; runbook step 3 explicitly covers relocation, so accepted. Consider absolute-path templating when the doctor grows a capture-session helper.
- Design touch worth noting: worker added `ALBION_HOOK_FIXTURE_DIR` redirect (not in the brief) so tests never pollute repo fixtures — accepted as within spirit of scope.

## Metrics running totals

| Metric | Value |
|---|---|
| Packets dispatched / accepted first-pass | 3 / 3 |
| Rework cycles | 0 |
| Blocking review findings | 0 |
| Worker tokens (OpenAI lane, cumulative) | 106,873 + ALB-002/005 pair ≈ 214k (per-console figures logged in handoff area) |

## Next

004 — ALB-003 (bin/albion launcher) dispatched; ALB-004 (doctor) follows, consuming ALB-002's env and ALB-005's fixtures.
