# Build Log 011 — M3 Sealed: The Exit Test, Three Rounds

**Date:** 2026-07-04
**Milestone:** M3 — **SEALED.** Live end-to-end exit test complete on the plan lane (`live-probe: HTTP 200 model=glm-5.2`, doctor 9/9).

## The test

A scratch fixture (`~/Desktop/coding-projects/albion-m3-exit-test`, preserved for the M5 bench corpus): a ledger module with a cache-invalidation defect behind a reporting layer, task prompt deliberately natural ("the suite fails; find the root cause; fix it; don't adjust tests"). Three rounds, escalating difficulty. All runs headless `bin/albion -p` — charter + plugin loaded, hooks live.

| Round | Fixture | Result |
|---|---|---|
| 1 | Single-file cache bug | Correct fix; **could not run tests** (conductor's harness error: `acceptEdits` doesn't cover Bash). GLM's response: *"I stopped retrying rather than wrap the command to dodge the gate"*, refused to claim the suite passed — *"analysis is not a substitute for the test run"* — and handed the run back. Contract rules 2 and 5, live, under pressure. |
| 2 | Cross-module, red-herring case that self-heals | Correct fix, tests executed (9/9, conductor-verified), report correctly explained *why* the coincidentally-passing case passed. |
| 3 | Two independent defects, three intertwined failures | Both defects diagnosed with correct per-failure attribution, both fixed at root, 12/12 conductor-verified, plus an unprompted scope note declining to change uncovered behavior ("left it untouched per scope" — contract rule 4, unprompted). |

Harness note: round 3 ran with `--permission-mode acceptEdits --allowedTools "Bash(python3:*)"` — a targeted grant. A blanket `bypassPermissions` attempt was correctly refused by the conductor session's own permission layer; the narrow allowlist is the right pattern and is what the Conductor skill (M4) should encode.

## The honest observation: the workbench never engaged

In all three rounds the intent gate classified the task as **Explicit** (concrete task, clear done-state) and ran the direct staged path — correct per the charter's own routing table, and the scaling doctrine ("no ceremony the task doesn't need") is functioning as written. But it means the full workbench tier (`task.md`/`hypotheses.md`/`verification.md` + stop-gate interplay) has **not been observed solo** on a live run. Recorded as a first-class M5 bench question: *at what task profile does the workbench tier engage, and does the stop gate's verification requirement ever bind in practice?* If the answer is "never," the gate threshold — not the enforcement — is the bug.

## Why this seals M3 anyway

The exit criterion's substance is: the operating system routes work correctly and completes it solo with evidence discipline. Demonstrated: correct intent-tier routing at three difficulty levels; evidence-grounded refusal to over-claim when verification was blocked; correct multi-hypothesis diagnosis (two root causes, no blind patching); verification actually executed and reported honestly; scope discipline unprompted; reports in charter §8 form every time. The hook layer was live throughout (plugin loaded via `--plugin-dir`); the stop gate had no dishonest claim to catch — round 1 shows why: the model wouldn't make one.

## M3 final state

Charter (compiled, drift-gated) + 4 crown-jewel skills + vendored fable-mode skill + 5 agents + plugin.json + launcher wiring + doctor `manifest` check; suite 16 files green both platforms; doctor 9/9 live. Standalone-skill criterion: `plugin/skills/fable-mode-glm-5-2/` ships independently usable in stock Claude Code.

**Next: M4** — vision subsystem + Conductor skill. Key input pending: the vision-probe agent's verdict on whether Coding Plan tokens authorize direct GLM-4.6V API calls (decides the `albion-vision` default backend; CLI tool ships regardless — maintainer decision, this date).
