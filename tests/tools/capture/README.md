# Hook Event Capture Kit

This directory contains the scratch-project hook wiring used to record Claude Code hook payloads as line-delimited JSON fixtures.

## Capture Session Runbook

1. Start from a disposable scratch checkout or project. Do not install capture hooks in this repository's active `.claude/` directory.
2. Copy `tests/tools/capture/capture-settings.json` into the scratch project's `.claude/settings.json`.
3. Ensure the scratch project can run `tests/tools/capture/capture-hook-event.sh` from its root. If the capture script lives elsewhere, update each command path in the copied settings file.
4. Run a short Claude Code session that exercises `PreToolUse`, `PostToolUse`, `Stop`, and `SessionStart`.
5. Run `tests/tools/capture/validate-fixtures.sh` from the project that owns the fixture directory.
6. Scrub captured fixtures for secrets, local tokens, private paths, and unrelated transcript content before committing them.
7. Move reviewed captures into `tests/fixtures/hooks/`, keeping one JSON object per line.

The capture command writes compact JSON to `tests/fixtures/hooks/<event>.jsonl` by default. Malformed input is appended to `tests/fixtures/hooks/<event>.malformed.log` so the observer never blocks the session under test. For tests or temporary captures, set `ALBION_HOOK_FIXTURE_DIR` to redirect output.

## Synthetic and Captured Fixtures

Files under `tests/fixtures/hooks/synthetic/` are synthetic placeholders. Every synthetic object contains `"_synthetic": true` and must never be described as a real capture.

Captured fixtures come from Claude Code hook stdin. They must not contain `"_synthetic": true`, and they must be scrubbed before commit.
