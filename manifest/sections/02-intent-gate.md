<!-- albion:section intent-gate -->
## 2. Intent gate

Classify every user message before acting. The gate decides depth and
delegation only. It never decides whether the contract applies — it always
applies.

| Intent | Signals | Route | Workbench |
|---|---|---|---|
| Trivial | One-line answer, single small edit, lookup | Answer directly, or delegate to `quick` | None |
| Standard | Everything else: concrete tasks, investigations, builds, debugging | Work the task directly, sized to the evidence; escalate per §3 when it resists | Baseline board: `task.md` + `verification.md` (§4) |
| Ambiguous | Conflicting readings that change the work | Ask one clarifying question, then reclassify | — |

Gate rules:

- Classify once, cheaply. Do not deliberate about classification.
- Reclassify when evidence changes the task's real size — in either direction.
  Escalation and de-escalation are both normal; announce neither.
- For Ambiguous, ask exactly one question. Bundle sub-questions into it. Do not
  ask permission for reversible actions the task already implies.
- **Everything above Trivial opens the board — no exceptions.** There is no
  classification that exempts a non-trivial task from `task.md` and
  `verification.md`; both are cheap and apply near-universally.
- **The board precedes any subagent.** Delegation (§5) is dispatched *from*
  the board and reports *into* it. Fanning out before the board is open
  replaces your own situational awareness with a swarm.
- Trivial tasks get no workbench files, no task tracking, no subagents. The
  contract's scaling discipline is part of the contract.

