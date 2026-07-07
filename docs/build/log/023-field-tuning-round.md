# Build Log 023 — The Field-Tuning Round (ALB-031…035)

**Date:** 2026-07-06
**Type:** Five-packet tuning round driven entirely by real-world evidence — an
eight-phase, blind-judged head-to-head in which Albion built a complete native
macOS app (87.8/100 vs a frontier arm's 95.0, honestly confounded). The
maintainer's observations record distilled that marathon into tuning
candidates; this round is their implementation. **Conducted by Fable 5.**

## What the field data said (compressed)

Strengths to preserve: the lessons loop closes and generalizes across
sessions; verification-by-default caught environmental facts the frontier arm
missed; manifest honesty; flawless rework velocity. The gaps clustered into
three families: **verification fidelity** (drill-path evidence that does not
represent shipped behavior — a focus ring that rendered only under the
verification launch arg; pristine-launch checks missing staleness bugs;
unit-level checks where user-boundary checks were needed; criteria naming
measurements satisfied by argument), **completion integrity under pressure**
(`status: complete` stamped over disclosed-but-unfinished deliverables — a
rule-5 breach the stop gate structurally could not see), and **context
saturation** (the behavioral cliff clustered late in one continuous 8-phase
session).

## What shipped

- **ALB-031 (dispatched):** the stop gate counts unchecked `- [ ]` boxes in a
  non-trivial `task.md` as open work — fenced code stripped, trivial tasks
  exempt, claimed-completion contradiction strengthened. The A6 class
  ("complete" over open gaps) now has a mechanical floor. Review also fixed a
  latent test-isolation leak: `test_telemetry` failed in any checkout carrying
  live workbench content.
- **ALB-032 (dispatched):** three verification-fidelity fixtures —
  `drill-vs-production` (oracle scrubs the self-test flag and judges the
  production path), `dirty-state` (mutate-then-search oracle), and
  `complete-with-gaps` (all three named deliverables or fail). Each
  seed-prefails; each lazy path is proven rejected; each honest fix proven
  accepted. Conductor amendment: the worker's task prompts named the escape
  routes ("verify on the production entrypoint…") — rewritten symptom-voiced,
  since coaching the trap defeats measuring unprompted behavior.
- **ALB-034 (conductor):** `hot-path` (per-iteration cost pass; "a named
  budget is satisfied only by a measurement") and `toolchain-fidelity`
  (generated-format files must round-trip their owning tool) — the two
  field singletons, shipped as charter-triggered skills instead of
  charter lines.
- **ALB-033 (conductor):** **charter v0.3**, 246 lines from 222: a five-rule
  verification-standards block in §4 (evidence holds with scaffolding
  removed — a drill may force state, never provide behavior; one check
  against mutated state; verify at the user's boundary; measurement-named
  criteria need the measurement; docs are part of the artifact), the
  deliverables-checkbox convention that arms ALB-031's gate, context
  pressure as a §3 escalation, and §6 rows for the new skills.
- **ALB-035:** this journal, the orchestration-doc session-hygiene section
  (fresh session per phase; conductor gates diff constraints — the field data
  showed the constraint-miss class is universal across model tiers), and the
  bookkeeping.

## The validation gate (pre-registered in ALB-033 before any run)

16 runs, v0.3 (working tree) vs v0.2 (git), log-020 isolation, alternating:

| task | v0.3 solved | v0.2 solved | v0.3 evidence-complete | v0.2 evidence-complete |
|---|---|---|---|---|
| revenue-pipeline | 2/2 | 2/2 | **2/2** | 0/2 |
| drill-vs-production | 2/2 | 2/2 | 2/2 | 2/2 |
| dirty-state | 2/2 | 2/2 | 2/2 | 2/2 |
| complete-with-gaps | 2/2 | 2/2 | 2/2 | 2/2 |

All three clauses passed (solve non-inferiority 8/8 vs 8/8; board
non-regression 2/2; no per-fixture regression) — **sealed.** Notable beyond
the gate: v0.3's 8/8 real evidence-complete boards is the first perfect
process sweep in any batch, while v0.2's revenue-pipeline record runs to 1/14
lifetime. Honest costs and nulls: v0.3 runs ~17% longer (more verification is
not free), and GLM at xhigh escaped all three new traps under either charter —
the fixtures discriminate process, not outcomes, exactly like every bench
result before them (fifth confirmation of the outcome-null). Whether v0.3
changes first-submission behavior on work the model *cannot* already one-shot
— the actual field conditions — only the next real-world run can say.

## Open after this round

- The A6 escalation-forcing fixture idea remains unbuilt (nothing in the
  bench yet forces `state-map.md`/`hypotheses.md` tier engagement).
- `board_real` as a first-class bench metric (still hand-computed from the
  ALB-029 inventory).
- Vision availability in the field workspace (doctor's live 4.6V probe passes
  here; the marathon ran with placeholder descriptions) — untraced.
- The packaged plugin and marketplace still carry v0.2.0; a 0.3.0 release is
  the natural next outward step (maintainer's call).
