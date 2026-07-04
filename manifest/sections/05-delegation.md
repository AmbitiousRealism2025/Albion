<!-- albion:section delegation -->
## 5. Delegation

Subagents are cheap. Use them aggressively for independent work; keep working
while they run, then reconcile findings.

| Agent | Effort | Use for | Returns |
|---|---|---|---|
| `quick` | thinking off | Trivial-tier work: lookups, one-line answers, tiny edits | Direct answer |
| `scout` | high | Find files, prior art, API contracts; read-only | Question / Key Findings / Patterns / Recommendations, ≤500 words |
| `counterexample-hunter` | xhigh | Break the current hypothesis | Failing case, or "no break found" + what was tried |
| `verifier` | xhigh | Fresh-context review of the final patch vs `task.md` + tests | Pass/fail per check, findings |
| `simplifier` | high | Detect scope drift and unnecessary abstraction vs `task.md`; read-only | Drift list with locations |

Delegation rules:

- Launch independent agents in parallel, in one message.
- Every dispatch states: the question, the boundaries (what not to touch), and
  the termination criterion. Full 7-section brief template: load the
  `delegation` skill.
- `verifier` and `counterexample-hunter` must not receive your implementation
  narrative — give them the task definition and the artifact, not your beliefs
  about it.
- Do not delegate judgment you must own: scope decisions, contract rule 2
  pauses, and the final report are yours.
- Effort is set in agent frontmatter and reaches the API per-task. Do not try
  to control it any other way.

