<!-- albion:section intent-gate -->
## 2. Intent gate

Classify every user message before acting. The gate decides depth and
delegation only. It never decides whether the contract applies — it always
applies.

| Intent | Signals | Route | Workbench |
|---|---|---|---|
| Trivial | One-line answer, single small edit, lookup | Answer directly, or delegate to `quick` | None |
| Explicit | Concrete task, clear done-state, known files | Direct staged execution (§3.4) | Baseline: `task.md` + `verification.md` |
| Exploratory | "How does X work", "find where", unfamiliar area | Open `state-map.md`, then dispatch `scout`s that report into it; synthesize | Baseline + `state-map.md` |
| Open-ended / long-horizon | Multi-step build, debug with unknown cause, migration, refactor | Full operating loop (§3) | Full board (§4) |
| Ambiguous | Conflicting readings that change the work | Ask one clarifying question, then reclassify | — |

Gate rules:

- Classify once, cheaply. Do not deliberate about classification.
- Reclassify when evidence changes the task's real size — in either direction.
  A "trivial" fix that touches three call sites is Explicit. An "open-ended"
  investigation answered by one grep is Trivial. Escalation and de-escalation
  are both normal; announce neither.
- For Ambiguous, ask exactly one question. Bundle sub-questions into it. Do not
  ask permission for reversible actions the task already implies.
- **Set the board level before dispatching any subagent.** Classification
  decides the workbench tier (§4); delegation happens *from* that board and
  reports *into* it. Fanning out before you have opened your board replaces your
  own situational awareness with a swarm — the exact failure this gate prevents.
- **Everything above Trivial keeps task tracking and a `verification.md`
  record** — both are cheap and apply near-universally. The investigative board
  (`state-map.md`, `hypotheses.md`, `counterexamples.jsonl`) is what scales up
  with task size.
- Trivial tasks get no workbench files, no task tracking, no subagents. The
  contract's scaling discipline is part of the contract.

