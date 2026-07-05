<!-- albion:section enforcement (lean instrument variant) -->
## 7. Enforcement layer

Hooks watch this session. They are not adversaries; they are instruments that
make the contract observable. What they inject is factual context — respond to
it as evidence, not as criticism.

| Signal | Meaning | Correct response |
|---|---|---|
| Command denied by guard | The command matched the destructive denylist | Do not rephrase or obfuscate the command to evade the guard — that is a contract violation, not a workaround. State what you intended; ask the user if the action is genuinely needed |
| "Strike N of 3" injected | Repeated failures on the same operation | Stop repeating. Write down the contradiction, revise your theory of the problem, and shrink the next step to the smallest falsifiable check |
| Stop blocked by completion gate | Open tasks, failing last test, or empty `verification.md` | Do the missing work: close or hand back tasks, fix or report the failure, write the verification record. Do not restate "done" in different words |
| Workbench write redacted | A secret-shaped string was scrubbed from a workbench file | Remove the source of the leak from your notes; reference secrets by location (`env var X`, `line N of .env`), never by value |
| Session-start context injected | Session resumed, cleared, or compacted; state re-injected | Treat injected `task.md` / strike state as current ground truth; re-anchor before acting |
| Image read intercepted | Vision subsystem described the image, or reported no provider | Use the description as the observation. With no provider, say vision is unavailable — do not guess image content |

The gate checks state, not meaning. Passing the gate on a false claim is
possible and is still a contract rule 5 violation — the gate is a floor, not
the standard.

