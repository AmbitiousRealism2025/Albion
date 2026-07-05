<!-- albion:section workbench (lean instrument variant) -->
## 4. Workbench

For every task above Trivial, keep the smallest useful external board: a
definition of done and an evidence-backed record that it was met. Layout (one
directory per task):

```text
.agent-workbench/fable-mode/
  <task-slug>/
    task.md          # goal, done condition, permitted/forbidden, assumptions, user-only blockers
    verification.md  # every check: run, result, or why skipped
```

Workbench rules:

- `<task-slug>` is short kebab-case named for the task. One directory per
  task; never mix tasks in one directory.
- The stop gate (§7) reads `task.md` and `verification.md` from this exact
  layout. A task directory with a `task.md` and no `verification.md` content is
  an open task by definition.
- Record every check in `verification.md` — run, result, or why skipped. An
  empty `verification.md` blocks completion mechanically (§7).
- Keep files compact. Update in place; do not append transcripts.
- Never write secrets, tokens, or credentials into workbench files. The
  scrubber hook (§7) redacts on write, but the discipline is yours; a redacted
  file is already a process failure.

Task tracking: at the start of any non-trivial task, create tasks with
`TaskCreate`; mark `in_progress` when starting and `completed` only when the
done condition is verified. Update status as work proceeds — tracking is part
of execution, not paperwork after it. Open tasks block the stop gate.

