# Build Log 012 — M4 Sealed, and the Hooks That Never Fired

**Date:** 2026-07-04
**Milestone:** M4 — vision subsystem + conductor protocol. **Status: SEALED** (both exit criteria live-verified). Also contains the most important correctness finding of the build.

## The headline: the enforcement layer had never been on

M4's manifest exit test failed silently — worker finished, no manifest, and **no session state at all**. Root cause, isolated by three live probes (settings hook: fires; minimal string-command plugin hook: fires; our plugin: never): `plugin/hooks/hooks.json` declared every command as an **array** (`"command": ["…"]`), a form Claude Code silently ignores. Since ALB-012 wired them — through the M2 seal, the adversarial red-team, and all three M3 exit-test rounds — **every Albion hook was inert in real sessions.**

Two honest consequences:

1. **The M3 exit rounds were an accidental clean A/B of the charter alone.** GLM's exemplary behavior there (evidence discipline, refusing to dodge the permission gate, scope restraint) was pure prompt-layer, zero enforcement. The charter carries more weight than we had proof of.
2. **The verification stack had a shared blind spot one layer above the wire format.** `verify-hooks.sh`, the doctor's hook-suite, and `test_hooks_wiring.sh` all validated hook *behavior* by invoking scripts directly; the wiring test actually **enforced the wrong array schema** ("command must be exec-form list"). Nothing tested *registration* — whether Claude Code loads the hooks at all. Atreides' indictment was "466 tests, zero against the wire format"; ours was "recorded-payload tests against the wire format, zero against the loader."

**Fixes (pushed CI-green, `57dcdae`):** all six commands are strings; the wiring test asserts the string schema with the wire-verified rationale inline; live re-probe shows first-ever real-session hook activity (strike-counter state + a valid v1 completion manifest). **Backlog (M5/M6):** a registration smoke-check — one cheap headless session with a marker hook — so this class can never silently regress.

**Lesson (CONVENTIONS-class):** a config file is not verified until the *consumer that loads it* has been observed acting on it. Testing the artifact's schema against your own reading of the spec verifies your reading, not the wire.

## M4 deliverables (all live-verified)

- **ALB-017 `bin/albion-vision`**: direct GLM-4.6V, both lanes, no MCP (per research report 11's probe: plan tokens work on `/api/anthropic`; paas/v4 1113s them). Live: HTTP 200 + real description; doctor `--live` 10/10.
- **ALB-018 image-read interception** (sixth hook): descriptions delivered via the wire-verified deny-reason channel; degrade notes for unsupported types/failed vision; env-secret scrubbing in reasons. **Full-session live test:** GLM-5.2 asked to read an image answered from the vision description and *attributed it honestly* ("the image bytes were not loaded directly; this description comes from the vision subsystem") — transparency held end-to-end.
- **ALB-019 completion manifest**: allow-path-only atomic write, absolute fail-open. Live: manifest written by a real worker's clean stop.
- **ALB-020 conductor skill**: dispatch/poll/review/recovery/release, loop-guard caveat included.

## Exit tests

1. **Transparent image read** — pass (above).
2. **Conductor dispatches worker, reviews manifest** — pass: re-seeded ledger fixture, worker dispatched per the skill's own command shape, manifest polled as the done-signal, content checks applied (`open_task_count` 0; `last_test: unknown` treated as review input per the skill), conductor review confirmed the correct fix with untouched tests.

## Worker-lane discipline watch (post-gaming)

Three packets this milestone hit out-of-scope test breakage (`test_doctor.sh` tallies twice, `test_plugin_manifest.sh` counts once). **All three reported and stood down** per the standing brief clause — the ALB-016 counter-gaming has not recurred. Conductor responses: tallies fixed empirically against observed output; the manifest test now derives counts from the manifest (invariant, not constant); ALB-018's one-line `test_capture.sh` update was technically out-of-list but necessitated by a sanctioned fixture — accepted, and briefs now enumerate fixture-adjacent tests explicitly.

Also fixed in conductor review: the conductor skill's frontmatter description contained an unquoted `: ` (strict-YAML hazard for real frontmatter parsers); validated with a real YAML parse after the fix.

## Observations carried to M5 (bench questions)

1. Workbench tier still never engages solo (all exit runs classify Explicit) — now testable *with enforcement actually on*.
2. `last_test` lands as `unknown` in the manifest even when the worker ran the suite — the strike hook's test-detection heuristics may be too narrow; measure and tune.
3. GLM-4.6V description quality on degenerate/tiny images is poor (2×2 pixels read as "uniform gray"); fine for real screenshots, worth a bench case.

## Metrics (milestone)

| Metric | Value |
|---|---|
| Packets dispatched / accepted | 4 / 4 (zero rework dispatches) |
| Genuine defects found | 1 critical (inert hooks, conductor-found), 1 latent (YAML frontmatter hazard) |
| Out-of-scope conflicts reported honestly by workers | 3/3 (post-gaming record intact) |
| Live probes run by conductor | 8 (vision CLI, doctor live ×2, hook direct, registration isolation ×3, full-session image read) |
| Test suite | 19 files, green both platforms; CI 5/5 green this milestone |
