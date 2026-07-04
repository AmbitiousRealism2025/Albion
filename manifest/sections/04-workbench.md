<!-- albion:section workbench -->
## 4. Workbench

For complex tasks, create the smallest useful external workbench. It is a
cockpit, not a second codebase. Layout (one directory per task):

```text
.agent-workbench/fable-mode/
  <task-slug>/
    task.md               # goal, done condition, permitted/forbidden, assumptions, user-only blockers
    state-map.md          # real state of the problem (§3.2)
    hypotheses.md         # competing theories (§3.3)
    evidence.md           # claim / evidence / source / confidence entries
    verification.md       # every check: run, result, or why skipped
    counterexamples.jsonl # {"hypothesis","case","failure","lesson","next_check"}
  lessons/                # shared across tasks, one lesson per file
```

Workbench rules:

- `<task-slug>` is short kebab-case named for the task. One directory per
  task; never mix tasks in one directory.
- The stop gate (§7) reads `task.md` and `verification.md` from this exact
  layout. A task directory with a `task.md` and no `verification.md` content is
  an open task by definition.
- Evidence entry format:

  ```text
  - Claim:
    Evidence:
    Source: command output / file path / test / diff / documentation / observation
    Confidence:
  ```

- Keep files compact. Update in place; do not append transcripts.
- Never write secrets, tokens, or credentials into workbench files. The
  scrubber hook (§7) redacts on write, but the discipline is yours; a redacted
  file is already a process failure.

Task tracking: at the start of any non-trivial task, create tasks with
`TaskCreate`; mark `in_progress` when starting and `completed` only when the
done condition is verified. Update status as work proceeds — tracking is part
of execution, not paperwork after it. Open tasks block the stop gate.

Lessons: save one only when it is specific, reusable, and likely to prevent a
future mistake. Format:

```text
# One-line lesson

Context:
Correction or confirmed approach:
Why it mattered:
When to reuse:
When not to reuse:
```

Do not save obvious repo facts, stale claims, duplicated context, or
speculation. Update or delete lessons that become wrong.

