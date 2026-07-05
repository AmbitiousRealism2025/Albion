# Build Log 021 — Lean Charter: n=6 Headless + the Interactive Recovery Test

**Date:** 2026-07-05
**Type:** Conductor-run experiment, continuing log 020 (charter-trim track).
**Conducted by Fable 5**, verified at session start.

## Headless, n=6 per arm

Three more runs per arm (same method as log 020: `env -i` scrub, per-arm
`CLAUDE_CONFIG_DIR`, alternating order). Full matrix, 12 runs:

| measure | full (350 lines) | lean (138 lines) |
|---|---|---|
| solved | 6/6 | 6/6 |
| board dir present (`engaged`) | 2/6 | 4/6 |
| real board (non-empty `task.md`) | 1/6 | 4/6 |
| evidence-complete | 1/6 | 4/6 |

The log-020 "0/3 pure inversion" softened, as small n warned it might: the
full charter *can* open a board headless (full-4 did, completely). But the
direction held on every measure, and a texture emerged: **when lean opened a
board it was always complete (4/4); the full arm's second "engagement"
(full-5) was a `check_fix.py` script dropped in a task-slug directory — no
`task.md`, no `verification.md`.** The ALB-029 artifact inventory is what made
that adjudication possible; the stop gate had (correctly, by its own rule)
ignored the dir. Candidate metric refinement for a future packet: a
`board_real` flag (any task dir with non-empty `task.md`) between `engaged`
and `evidence_complete`.

Statistics stay honest: 1/6 vs 4/6 is Fisher one-tailed p≈0.14. Direction,
consistent across measures and batches — not significance.

## Interactive lean run: engagement + the recovery ripcord

One interactive session (log-018 tmux protocol: scrubbed env, fresh
`CLAUDE_CONFIG_DIR`, TUI verified `glm-5.2[1m] with xhigh effort`), lean
charter, same fixture. Scorecard:

- **Board engaged**: `task.md` (30 lines) + `verification.md` (26 lines),
  evidence-complete; task tracking used (`TaskCreate`, one task through
  in-progress → done).
- **Solved**: suite 4/4, hash fixture intact, one-token fix, clean scope.
- **Final report quality**: root cause with both failure lanes (day>12
  ValueError → epoch fallback → no FX rate → 0.0; day≤12 silent month/day swap
  → wrong rate), validation, and a scope check.
- **Recovery ripcord — the reason for the run**: after a forced `/compact`,
  the probe ("what task, what root cause, is it verified?") came back **cited
  line-by-line from the board** — `task.md:3–8` (task), `task.md:10–16` (root
  cause), `verification.md:16–24` + the hash fixture (verification) — plus the
  SessionStart hook's re-injected state. The log-018 recovery behavior, fully
  reproduced under the lean document.

Method friction, recorded honestly: the first prompt submission was swallowed
by the TUI (bracketed-paste Enter — send Enter separately), and the run needed
two manual permission approvals (`python` and `shasum` fall outside the
fixture's `python3:*` allowlist). Wall-time for this run is therefore not
comparable and is not reported. Also filed: the conductor's first batch
driver hit the bash-3.2 `set -u` empty-array expansion — the project's own
portability convention, proven again on the project's own tooling.

## Where the trim question now stands

Everything the full charter has ever demonstrably bought — board engagement,
evidence-complete verification records, task tracking, compaction recovery
with citations — the 138-line lean composition has now been observed to buy
too, plus *more reliable* headless engagement (direction only, p≈0.14).
Nothing observed so far is worse under lean; 12/12 + 1 interactive runs all
solved regardless (outcome-null, fourth confirmation).

**Decision now sits with the maintainer** (per the one-charter rule): adopt
the lean composition as the trim of the shipped charter, run more n first, or
keep the full charter and treat headless board unreliability as acceptable.
What has NOT been tested under lean: delegation-heavy work (the lean document
drops the delegation table — subagent behavior was not exercised by this
fixture), multi-session continuity, and the investigative board tiers on a
task that genuinely needs `hypotheses.md`. Any adoption decision should weigh
those uncovered surfaces, and probably keeps their sections in some form.

Instrument unchanged from log 020, archived at
`docs/build/experiments/lean-charter-v1/`; raw run dirs in the session
scratchpad (12 headless records + 1 interactive workspace).
