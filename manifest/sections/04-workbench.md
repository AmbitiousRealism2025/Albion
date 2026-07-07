<!-- albion:section workbench -->
## 4. Workbench

For every task above Trivial, keep the smallest useful external board: a
definition of done and an evidence-backed record that it was met. It is a
cockpit, not a second codebase. Layout (one directory per task):

```text
.agent-workbench/fable-mode/
  <task-slug>/
    task.md               # goal, done condition, deliverables checklist, permitted/forbidden, assumptions
    verification.md       # every check: run, result, or why skipped
    state-map.md          # on escalation (§3)
    hypotheses.md         # on escalation (§3)
    counterexamples.jsonl # on contradiction: {"hypothesis","case","failure","lesson","next_check"}
  lessons/                # shared across tasks, one lesson per file
```

Workbench rules:

- `<task-slug>` is short kebab-case named for the task. One directory per
  task; never mix tasks in one directory.
- The stop gate (§7) reads `task.md` and `verification.md` from this exact
  layout. A task directory with a `task.md` and no `verification.md` content is
  an open task by definition.
- Deliverables live in `task.md` as a checkbox list. A box is checked only
  when its done condition is verified; the stop gate counts unchecked boxes
  as open work.
- Record every check in `verification.md` — run, result, or why skipped. An
  empty `verification.md` blocks completion mechanically (§7). Before the
  final report, audit every progress claim against this file or direct tool
  output — and audit `task.md`'s constraints the same way: an unmet or
  unverified constraint is disclosed, never omitted.
- Keep files compact. Update in place; do not append transcripts.
- Never write secrets, tokens, or credentials into workbench files. The
  scrubber hook (§7) redacts on write, but the discipline is yours; a redacted
  file is already a process failure.

Verification standards — evidence quality is part of the contract:

- Evidence must hold with all verification scaffolding removed. A drill may
  force *state*, never provide the *behavior*; a check that only passes with
  a test flag set has verified the flag.
- At least one check runs against mutated, lived-in state. Fresh launches
  systematically miss staleness.
- Verify at the boundary the user touches, not the boundary that is
  convenient.
- An acceptance criterion that names a measurement is satisfied only by that
  measurement.
- Documentation that describes the artifact is part of the artifact.

Task tracking: at the start of any non-trivial task, create tasks with
`TaskCreate`; mark `in_progress` when starting and `completed` only when the
done condition is verified. Update status as work proceeds — tracking is part
of execution, not paperwork after it. Open tasks block the stop gate.

Lessons: save one only when it is specific, reusable, and likely to prevent a
future mistake — context, correction, why it mattered, when to reuse. Update
or delete lessons that become wrong.

