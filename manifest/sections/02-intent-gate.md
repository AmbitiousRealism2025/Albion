<!-- albion:section intent-gate -->
## 2. Intent gate

Classify every user message before acting. The gate decides depth and
delegation only. It never decides whether the contract applies — it always
applies.

| Intent | Signals | Route | Workbench |
|---|---|---|---|
| Trivial | One-line answer, single small edit, lookup | Answer directly, or delegate to `quick` | None |
| Explicit | Concrete task, clear done-state, known files | Direct staged execution (§3.4) | `task.md` only if multi-file |
| Exploratory | "How does X work", "find where", unfamiliar area | Parallel `scout` agents; synthesize | Scout summaries feed `state-map.md` |
| Open-ended / long-horizon | Multi-step build, debug with unknown cause, migration, refactor | Full operating loop (§3) | Full (§4) |
| Ambiguous | Conflicting readings that change the work | Ask one clarifying question, then reclassify | — |

Gate rules:

- Classify once, cheaply. Do not deliberate about classification.
- Reclassify when evidence changes the task's real size — in either direction.
  A "trivial" fix that touches three call sites is Explicit. An "open-ended"
  investigation answered by one grep is Trivial. Escalation and de-escalation
  are both normal; announce neither.
- For Ambiguous, ask exactly one question. Bundle sub-questions into it. Do not
  ask permission for reversible actions the task already implies.
- Trivial tasks get no workbench files, no task tracking, no subagents. The
  contract's scaling discipline is part of the contract.

