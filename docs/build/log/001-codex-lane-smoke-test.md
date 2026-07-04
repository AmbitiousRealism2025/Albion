# Build Log 001 — Codex Lane Smoke Test

**Date:** 2026-07-04
**Phase:** planning (pre-dispatch verification of the implementation lane)

## What was tested

One trivial packet through the exact dispatch shape the build will use: headless `codex exec`, sandboxed, with the final message written to a file as the completion signal.

```
codex exec --skip-git-repo-check --sandbox read-only \
  --output-last-message <handoff>/last.md \
  "Reply with exactly this string and nothing else: ALBION-SMOKE-OK"
```

## Result: PASS

- Exit code 0; process exit is a clean completion signal (no screen-scraping needed).
- `last.md` written with exactly `ALBION-SMOKE-OK` — the file-based handoff works.
- Token usage reported in-stream (19,235 for the trivial round trip) — usable for the cost-per-lane metric.
- Environment: Codex CLI 0.142.2, tmux 3.6a.
- Lane defaults already match the target configuration: `model = "gpt-5.5"`, `model_reasoning_effort = "high"`, 400k context window — no per-dispatch overrides required.

## Notes for real dispatches

- Real packets will run `--sandbox workspace-write` scoped to the repo (`-C`), not read-only.
- Maintainer-side Codex hooks (UserPromptSubmit/Stop notifications) fire during exec runs; harmless, no protocol impact.
- The `--skip-git-repo-check` flag is unnecessary once dispatches run inside the Albion repo.

## Next

- 002 — Milestone 1 packet plan (maintainer-approved) and first real dispatches.
