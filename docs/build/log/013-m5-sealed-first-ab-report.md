# Build Log 013 — M5 Sealed: The First A/B Report

**Date:** 2026-07-04
**Milestone:** M5 — telemetry + three-arm A/B bench. **Status: SEALED.** First real A/B report produced over 6 tasks × 2 arms (12 live GLM-5.2 sessions on the plan lane). Report committed at `bench/reports/m5-first-ab-report.md`.

## What M5 delivers

- **`telemetry/albion-metrics`** — per-task metrics with a dual cost model; Claude Code's `total_cost_usd` is carried only as an untrusted passthrough (the fixture demonstrates it overstating real GLM cost 2.7×).
- **`last_test` writer** (ALB-022) — the strikes hook now records a key three consumers read and nothing wrote; the stop gate's failing-test block is reachable for the first time.
- **`bench/run-task`** — three-arm runner: setup → launch (`albion`/`vanilla`) → model-independent oracle → embedded telemetry → `albion-bench-run/v1` record.
- **`bench/report`** — A/B aggregator with a *generated, mandatory* honest-notes section (explicit denominators, small-n disclaimer, named skips).
- **Corpus:** 6 hash-pinned, tamper-proof single-session bug hunts.

## The first report — read honestly

Both arms solved **6/6**. On tasks this size, the full Albion stack and bare GLM-5.2 are indistinguishable on correctness — and the honest conclusion is that **these tasks are too easy to discriminate the arms.** The project's own thesis says so: GLM-5.2's gap to Opus is on *long-horizon* work, and a single-bug fix is not long-horizon. The bench proves the harness works end-to-end; it does not yet prove Albion's value, because the corpus can't.

Measured differences (direction only, n=1 per cell):

| | albion | vanilla |
|---|---|---|
| Solve rate | 6/6 | 6/6 |
| Mean wall (solved) | 130s | 113s |
| Mean cost (prompt-equiv) | 0.769 | 0.694 |
| Workbench engagement | 0/6 | 0/6 |
| `last_test` fidelity | 5/6 | 0/6 |

**The honest reads:**

1. **Albion costs ~15% more wall time and ~11% more quota here for zero solve-rate gain.** That is the always-on charter + plugin overhead on tasks where it changes no outcome. This is the expected shape and must be stated plainly: on easy work, the enforcement layer is pure tax. Its value has to come from harder tasks, and the bench must grow toward them.
2. **The workbench tier never engaged — again, now with enforcement genuinely live.** All 12 sessions classified Explicit. This is the third consecutive confirmation (M3, M4, M5) and now the clearest: the workbench/hypotheses/verification discipline the charter describes has *never* been exercised by GLM-5.2 solo. Either the intent gate's threshold is too high or no task yet posed has warranted it. This is the headline question for the next corpus expansion — deliberately long-horizon, multi-file, unclear-cause tasks.
3. **`last_test` fidelity is 5/6 on albion, 0/6 on vanilla — both correct.** Vanilla loads no plugin, so it structurally cannot write the key; 0/6 is the right number, not a failure. Albion's 5/6 confirms the ALB-022 detection working in the wild. The one miss (peak-window) is a genuine low-frequency gap: detection provably matches its test commands and the write path is provably unconditional, yet that session's state lacks even the strikes key — pointing at a per-run hook-invocation or state-write hiccup, not a pattern gap. Filed for a dedicated repro (M6 backlog); not chased further here because a single-sample heisenbug does not block a seal.

## Two conductor-caught process failures this cycle

1. **The gamed-counter's cousin, benign this time:** the first 12-session batch logged "ALL RUNS COMPLETE," but six sessions had exited 1 *instantly* — my three new `setup.sh` files were mode 644 (the Write tool doesn't set +x; the runner exec'd them directly). Reading per-session exit codes, not the summary line, caught it. Zero model quota was spent on the failures. Fix: `chmod +x` the scripts **and** harden `bench/run-task` to invoke `bash setup.sh`/`bash verify.sh` so a missing executable bit degrades gracefully instead of failing a run silently. Lesson reinforced: a batch that reports success is not verified until each unit's exit code is read.
2. **A brief arithmetic error I made** (ALB-021's expected cost value) was caught and reported by the *worker*, which pinned to the formula and flagged the discrepancy rather than silently matching. The honesty norm is bidirectional now.

## Metrics (milestone)

| Metric | Value |
|---|---|
| Packets dispatched / accepted | 4 / 4 (ALB-021…024), zero rework dispatches |
| Genuine defects found | `last_test` never-written (pre-dispatch diagnosis); module-form detection gap (live-caught); non-exec setup.sh (live-caught); runner exec-vs-bash fragility |
| Out-of-scope conflicts reported honestly by workers | 2/2 (record intact since ALB-016) |
| Live GLM sessions run | 12 (+ ~3 smoke) on the plan lane |
| Test suite | 22 files green both platforms |

## Carried to M6 (OSS release) and the next bench pass

- **Grow the corpus toward long-horizon tasks** — the only way to test Albion's actual thesis; current tasks bottom out the discrimination.
- **peak-window `last_test` miss** — dedicated repro of the per-run state-write gap.
- **Charter-overhead is real and measured** — the A/B must keep reporting it honestly; it is the cost side of the value equation, and a grant reviewer should see it stated, not hidden.
