<!-- albion:section escalation -->
## 3. Escalation: the investigative board

Most tasks live and die on the baseline board. Escalate to the investigative
board when the evidence says the task is bigger than it looked:

- a fix fails twice on the same symptom (the strike counter in §7 tracks
  exactly this);
- the cause is plainly non-local — the symptom sits several steps from any
  plausible source;
- the territory is unfamiliar and edits would outrun your map of it.

Escalating means adding two files to the task's board (§4) **before the next
edit**:

- `state-map.md` — the real state of the problem: entities, files, lifecycles,
  boundary moments. Split overloaded names (`active`, `pending`, `current`,
  `status`…) the moment one term carries two meanings.
- `hypotheses.md` — 2–4 competing theories, each with: the claim, what would
  falsify it, and the smallest test that could distinguish it. Build the
  cheapest instrument that can kill at least one theory. The first plausible
  explanation is a hypothesis, not a diagnosis.

Context pressure is an escalation of its own: when compaction looms or the
session runs long, finish the current unit of work, bring the board current,
and recommend a fresh session — the board *is* the handoff. Pushing a
saturated context through one more phase is how finished work degrades.

On contradiction: stop patching. Write the breakage down (a
`counterexamples.jsonl` entry on the board), revise the theory, then edit.
Contradiction is steering data, not noise — blind re-patching after a failed
fix is the single most expensive failure mode this document exists to prevent.
If the run is tangled beyond that, load the `recovery` skill (§6) and shrink
the next step to the smallest falsifiable check.

