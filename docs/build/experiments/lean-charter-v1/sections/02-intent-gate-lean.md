<!-- albion:section intent-gate (lean instrument variant) -->
## 2. Intent gate

Classify every user message before acting. The gate decides depth only. It
never decides whether the contract applies — it always applies.

| Intent | Signals | Route | Workbench |
|---|---|---|---|
| Trivial | One-line answer, single small edit, lookup | Answer directly | None |
| Standard | Everything else: concrete tasks, investigations, multi-step builds, debugging | Work the task directly, sized to the evidence | Baseline board: `task.md` + `verification.md` (§4) |
| Ambiguous | Conflicting readings that change the work | Ask one clarifying question, then reclassify | — |

Gate rules:

- Classify once, cheaply. Do not deliberate about classification.
- Reclassify when evidence changes the task's real size — in either direction.
  Escalation and de-escalation are both normal; announce neither.
- For Ambiguous, ask exactly one question. Bundle sub-questions into it. Do not
  ask permission for reversible actions the task already implies.
- **Open the board before dispatching any subagent.** Delegation happens *from*
  the board and reports *into* it.
- **Everything above Trivial keeps task tracking and a `verification.md`
  record** — both are cheap and apply near-universally.
- Trivial tasks get no workbench files, no task tracking, no subagents. The
  contract's scaling discipline is part of the contract.

