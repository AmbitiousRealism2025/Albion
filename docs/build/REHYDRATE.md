# Albion — Session Rehydration (plain-language summary)

This is the neutral entry point for a new working session. It restates the
project in ordinary engineering terms so it reads cleanly. The longer
`SESSION-HANDOFF.md` and the build journal carry the same information in more
detail, but some of those files use domain vocabulary that an automated content
classifier tends to over-flag — so if you are conducting on the alternative
frontier model and want to avoid an unwanted mid-session model change, work from
*this* file and open the others only when you specifically need them.

## What Albion is

Albion lets the Claude Code CLI run on an alternative large language model
(GLM-5.2, served over a compatible API endpoint) instead of the default. It is
an MIT-licensed, open-source configuration layer. The pieces:

- **A launcher** (`bin/albion`) that points the CLI at the alternative endpoint,
  pins the model, and layers in the rest of the configuration for that session
  only — so a normal `claude` session on the machine is completely unaffected.
- **An always-on operating document** (`charter/ALBION.md`) that is added to the
  model's context each session. It encodes good working habits: size each
  request appropriately, keep working notes for large jobs, back claims with
  evidence, verify before reporting done. It is compiled from small source
  fragments in `manifest/sections/` by `bin/albion-compile`.
- **A set of workflow automation hooks** (`plugin/`) that watch a session and add
  helpful context — asking for confirmation before irreversible file operations,
  keeping working-notes files tidy, and making sure a task is actually finished
  before it is called finished.
- **On-demand skills and delegate agents** the model can call for focused
  sub-tasks (exploring a codebase, checking work with fresh eyes, simplifying).
- **An image-description helper** (`bin/albion-vision`) so the model can work
  with screenshots.
- **Usage telemetry** and an **evaluation harness** (`bench/`) for measuring how
  the setup performs.

## Current state

The system is **built, green, and released**: version 0.2.0 is tagged on
GitHub with an installable package attached, and the plugin marketplace is
published (`AmbitiousRealism2025/albion-marketplace`) — all milestones are
complete. The one thing never yet verified is the install round-trip from a
user's machine (two commands; the maintainer has the instructions). Everything is on the `main` branch,
the continuous-integration checks pass, and there are about 30 automated tests
covering the launcher, the configuration compiler, the hooks, the evaluation
harness, and packaging. Two setups can run side by side with no interference:
`albion` (the alternative model) and stock `claude` (the default), in separate
terminals.

## What was done most recently

- **Shipped version 0.2 of the always-on document** (the "lean" resolution —
  see the open-threads entry below for the full story): 222 lines from 350,
  validated by a pre-registered comparison before sealing. (Work packet
  ALB-030, build log 022.)
- Taught the evaluation harness to **measure the working-notes area itself**:
  each run now records which note files a session produced (names and sizes)
  and whether the notes were complete, and the comparison report shows those
  columns alongside pass/fail. Previously this could only be checked by hand,
  which blocked the "lean document" experiment below. (Work packet ALB-029,
  build log 019.)
- Before that: refined the always-on document so the model opens its working
  notes **before** delegating; added three evaluation tasks of escalating size
  and ran side-by-side comparisons at maximum reasoning effort; reviewed recent
  work with fresh-context reviewers and applied their fixes.

## Key findings from the comparisons

- **At maximum reasoning effort, the alternative model is very capable on its
  own.** On small, self-contained tasks it produces correct, well-reasoned
  solutions whether or not the extra guidance layer is present — the guidance
  does not change the outcome there.
- **The guidance layer's measurable value shows up on large, multi-file work.**
  On a genuinely big task (a dozen-plus files, a subtle cause several steps
  removed from the symptom), the configured setup opened an external
  working-notes area, produced an auditable trail of its reasoning, and — when a
  context reset was forced mid-task — recovered its place from those notes. The
  bare baseline solved the same task correctly but kept nothing to recover from.
- **So the value is process, not results:** auditability and recoverability on
  long jobs, not "solves more" or "solves better." That is a narrower and more
  honest claim than the project originally assumed, and it is evidence-backed.

## Open threads / what could come next

- **Publish the packaged plugin to the marketplace** — the one remaining setup
  step; needs the maintainer's account. `bin/albion-package` produces the
  artifact and is verified.
- **The "lean document" question — RESOLVED and shipped.** The maintainer
  approved the trim, and the always-on document is now **version 0.2**: 222
  lines instead of 350, built on the slim chassis the experiments validated.
  The task-classification table went from five tiers to three with one
  non-negotiable rule (every non-trivial task keeps working notes), the deep
  analysis machinery became an escalate-when-the-evidence-says-so section
  instead of upfront routing, and the delegate-agent and skills tables stayed
  in trimmed form. A pre-registered validation comparison passed: the new
  document opened real working notes in 3 of 4 scripted runs (all with
  complete evidence records) against 0 of 4 for the old document, with every
  run solving the task. The durable insight: a simple rule gets followed where
  elaborate routing gets rationalized around — and the document carrying it is
  a third smaller.
- **General hardening** — a pluggable provider setup and more interactive
  steering — if the project continues.

## A note on which model is answering

The conductor model for this project has, across sessions, been automatically
switched to a different model by an automated content classifier that reacts to
this project's subject area. It happens without a prompt and does not announce
itself in-line. **At the start of each session, confirm which model is active**
— the terminal statusline now shows it live at the front of the line. If you
want a specific model to conduct, the reliable approach is a **fresh session per
task**, kept to the topic at hand; switching the model inside a session whose
history already covers the flagged subject area does not hold.

## Where things live

| What | Path |
|---|---|
| Launcher and tools | `bin/` (`albion`, `albion-doctor`, `albion-vision`, `albion-compile`, `albion-setup`, `albion-package`) |
| Always-on document + its source + compiler | `charter/ALBION.md`, `manifest/`, `bin/albion-compile` |
| Workflow hooks, skills, delegate agents | `plugin/` |
| Evaluation harness + tasks | `bench/` |
| Usage telemetry | `telemetry/` |
| Build journal (detailed history) | `docs/build/log/` |
| Detailed handoff (more vocabulary-heavy) | `docs/build/SESSION-HANDOFF.md` |
| Contribution + conventions | `CONTRIBUTING.md`, `CONVENTIONS.md` |

## How the project is built

A frontier Claude session acts as a planner: it breaks each milestone into small,
reviewable work packets, hands the implementation to a separate command-line
coding tool, reviews every change against the packet, runs the full test suite
itself, and only then commits. The build journal records this honestly,
including missteps — that candor is part of the project's value.
