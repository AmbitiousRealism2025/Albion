# Build Log 022 — Charter v0.2: the Trim, Validated and Sealed

**Date:** 2026-07-05
**Type:** Conductor-implemented packet (ALB-030; ALB-027 precedent — the
section prose is the design work). **Conducted by Fable 5.**
**Maintainer decision applied:** "the lean option is working where full barely
gets utilized — bring in lean" (2026-07-05), shaped per the conductor's
recommendation: lean chassis, untested capability re-added in trimmed form,
validation A/B as the acceptance gate.

## What changed

`charter/ALBION.md` v0.1-draft (350 lines) → **v0.2 (222 lines)**:

- **Intent gate rewritten to 3 tiers** (Trivial / Standard / Ambiguous) with
  the one non-negotiable board rule: everything above Trivial opens `task.md`
  + `verification.md` — no classification exempts a task from the board. The
  old 5-tier routing is what GLM classified its way around (logs 020–021).
- **The 103-line operating loop replaced by a 31-line escalation section
  (§3):** the investigative board (`state-map.md`, `hypotheses.md`,
  `counterexamples.jsonl`) triggers on evidence — a fix failing twice, a
  non-local cause, unfamiliar territory — instead of upfront classification.
  Absorbs the old §9 recovery essence; `09-recovery.md` deleted.
- **Workbench (§4)** keeps the exact stop-gate layout, with the investigative
  files marked escalation-tier; absorbs the old §3.6 claim-audit rule.
- **Delegation (§5) trimmed** (33→30 lines): agent table intact, rules
  tightened, brief template delegated to the `delegation` skill.
- Contract, skills, communication, re-anchor unchanged; enforcement updated
  only where it referenced dropped sections. Section numbering continuous 1–8;
  a grep audit shows every §N reference resolves.

Hooks, skills, agents, launcher, tests: untouched. The SessionStart injection
and strike hooks read workbench files that all still exist under the
escalation model. Suite 28/28, shellcheck batch clean, drift gate green.

## Validation (the acceptance gate)

4 headless runs per arm on `revenue-pipeline`, log-020 method, v0.2 (working
tree) vs. pre-trim charter (from git, `ALBION_CHARTER` override):

| arm | solved | real board | evidence-complete |
|---|---|---|---|
| v0.2 (222 lines) | 4/4 | **3/4** | **3/4** |
| pre-trim (350 lines) | 4/4 | 0/4 | 0/4 |

Gate required ≥2/4 real boards and 4/4 solved for v0.2: **passed**. Three
different task slugs, three complete evidence trails.

Two readings worth recording:

1. **The mechanism question from log 021 is answered as well as n allows:**
   compliance held at 222 lines with delegation/skills/escalation re-added, so
   the load-bearing change is the *gate structure*, not raw brevity. The
   5-tier gate gave the model room to route around the board; the 1-rule gate
   does not.
2. **Cumulative tally for the old full charter: 1/10 real boards** across
   logs 020–022 batches; lean-chassis documents (138-line instrument + v0.2):
   7/10. Pooled Fisher one-tailed p≈0.01 — with the caveat that the pool mixes
   two lean-chassis variants; per-batch comparisons individually stay
   directional.

## Honest limits

Same as log 021: delegation-heavy, multi-session, and genuinely
investigative-tier work remain unexercised by this fixture under the new
gate — the escalation section's *trigger* (fix-fails-twice, non-local cause)
has not yet fired in any bench run because GLM keeps solving the fixture
without needing it. A future fixture that forces escalation (ALB-031
candidate) would close that gap. The `board_real` metric refinement (ALB-030
candidate in log 021) remains open — this log computed it by hand from the
artifact inventory.

## Where this leaves the charter question

Closed, pending real-world contradiction. The value claim stays what log 018
made it — process, not outcomes — but the process now shows up reliably in
headless runs too, and the document carrying it is 37% smaller. The bench that
couldn't discriminate anything three cycles ago now catches a compliance
regression in a 30-minute A/B; that harness is the durable asset.
