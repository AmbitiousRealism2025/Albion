# Build Log 020 — Lean vs. Full Charter, Headless: the Inversion

**Date:** 2026-07-05
**Type:** Conductor-run experiment (charter-trim track, phase 2 — first
evidence). **Conducted by Fable 5**, verified at session start.

## Question

The maintainer's standing decision: Albion ships ONE charter; if parts are
vestigial, trim it — but only on evidence from a bench that can discriminate.
ALB-029 (log 019) gave the bench process metrics. This experiment supplies the
first lean-vs-full data.

## Instrument

A **138-line lean charter** (vs. the shipped 350) compiled from a variant
manifest: preamble, contract, communication, and re-anchor kept verbatim; the
intent gate rewritten to 3 tiers (Trivial / Standard / Ambiguous) with a single
board tier; the workbench reduced to the baseline board (`task.md` +
`verification.md`); the enforcement table kept with dangling references
removed; the operating loop, investigative-board tiers, delegation table, and
skills catalog dropped. Archived at `docs/build/experiments/lean-charter-v1/`
(recompiles byte-identical to the artifact the runs used). It is a throwaway
instrument, not a shipped mode.

## Method

3 runs per arm of `revenue-pipeline` (ALB-028, the only fixture that has ever
engaged the board) through `bench/run-task`, headless, both arms in **default
albion mode** (plugin + hooks + xhigh settings): only the injected document
differs (`ALBION_CHARTER` env override for the lean arm — already supported by
the launcher, zero product changes). Isolation per the log-018 lesson: `env -i`
scrub + fresh per-arm `CLAUDE_CONFIG_DIR`. Charter resolution verified by
dry-run under the same scrubbed env for both arms; plugin load verified by the
Stop gate's completion manifest in every run.

## Results

| run | solved | wall (s) | turns | board | evidence-complete |
|---|---|---|---|---|---|
| full-1 | yes | 136 | 31 | no | no |
| full-2 | yes | 150 | 25 | no | no |
| full-3 | yes | 196 | 31 | no | no |
| lean-1 | yes | 208 | 35 | **yes** | **yes** |
| lean-2 | yes | 185 | 33 | **yes** | **yes** |
| lean-3 | yes | 110 | 25 | no | no |

Aggregates (`bench/report`, ALB-029 columns): solve rate 3/3 both arms; wall
mean 161s (full) vs 168s (lean); cost 1.61 vs 1.72 prompt-equivalents;
`workbench_rate` and `evidence_complete_rate` **0/3 vs 2/3**.

Both lean boards were genuinely high quality: `task.md` with goal / done
condition / confirmed root cause / forbidden / assumptions, and a
`verification.md` recording before/after test output, invariant checks
(regional sums reconcile, no epoch-fallback leakage), and the hash-fixture
check.

## What this says (and doesn't)

1. **Robust half — the full charter produced zero board engagement headless
   (0/3), on the very fixture where it engaged interactively (log 018).** The
   board-opening behavior is modality-sensitive. And the failure is invisible
   to the enforcement layer by construction: the stop gate checks board
   *state*, so zero task directories reads as zero open tasks and the gate
   passes. "Board never opens" — the exact failure the log-43da57f gate tune
   targeted — survives headless, unenforced.
2. **Suggestive half — the lean document *improved* compliance (2/3), inverted
   from the naive expectation that more instruction buys more process.** A
   plausible mechanism: the lean gate's single rule ("everything above Trivial
   opens the board") is harder to classify around than the full gate's 5-tier
   routing, and a 138-line document keeps the rule closer to attention than a
   350-line one. But 0/3 vs 2/3 at n=3 is direction, not significance (Fisher
   exact p≈0.4, one-tailed p=0.2) — treat as a hypothesis with first evidence, not a
   conclusion.
3. **Third confirmation of the outcome-null:** 6/6 solved, comparable wall
   time. The document changes *process*, never *outcome*, at max effort.
4. ALB-029's metrics did their job first time out: the arms tie on every
   pre-existing column and split only on the new ones.

## What would settle it

- **More headless n** (cheap: ~3 min/run) to firm up 0/3 vs 2/3.
- **An interactive lean run** (log-018 tmux protocol) to check the lean
  document retains the full charter's interactive engagement and
  compaction-recovery — the one value the full charter has demonstrated that
  lean hasn't yet.
- If both hold, the trim decision goes to the maintainer with a concrete
  proposal: the lean composition *is* the candidate trim of the ONE charter.

## Housekeeping

Conductor pushes to `main` are session-authorized by the maintainer
(2026-07-05); the self-modification guard correctly refused to let the
conductor add its own standing permission rule — the maintainer adds it or
grants per-session.
