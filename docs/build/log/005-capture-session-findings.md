# Build Log 005 — M2 Opens: Real Capture Session, Two Real Findings

**Date:** 2026-07-04
**Phase:** Milestone 2 (conductor groundwork)

## What happened

The conductor ran the ALB-005 capture runbook for real: a scratch project wired with capture hooks, driven by a GLM-5.2 session launched through `bin/albion` itself — the launcher's first real workload. It took three attempts, and the failures were the valuable part.

**Attempt 1** died instantly: `400 [1211] Unknown Model` from Z.ai — and separately, Claude Code warned it had **forced permission mode to default** because `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` was set. **Attempt 2** (plain `glm-5.2` slots, scrub override) still died with 1211 — and the scrub warning persisted because the env script *clobbers deliberate pre-set overrides*. **Diagnosis:** the user-level `~/.claude/settings.json` pins `"model": "claude-fable-5[1m]"`; a pinned model ID bypasses slot mapping entirely and reaches Z.ai verbatim. The research probes had used clean config dirs — real user machines don't. **Attempt 3** with explicit `--model 'glm-5.2[1m]'` and scrub disabled: session completed, file created and verified.

## Findings → fixes (dispatched as ALB-M1-R2)

1. **Env script must not clobber deliberate overrides** — tuning/hardening vars become export-if-unset.
2. **`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` breaks headless `acceptEdits`** (forces default permission mode) — default flips to 0 with documented rationale; revisit as opt-in in M6.
3. **The launcher must pin `--model` explicitly** (`glm-5.2[1m]`, user `--model`/`ALBION_MODEL` override wins) — slot env vars are insufficient on machines with a pinned settings model.

Every one of these would have shipped broken for real users with model-pinned settings — caught only because the build dogfoods its own product.

## Captured corpus (imported, scrubbed, committed)

17 real hook payloads under `tests/fixtures/hooks/captured/`: PreToolUse ×8 (including a 6-event permission-denial loop — ideal guard-test material), PostToolUse ×3, SessionStart ×4, Stop ×2. Scrubbed of usernames and machine paths (including dash-encoded project-dir slugs — the first scrub pass missed those; the recheck caught it). Validator green across captured + synthetic sets.

## Dispatched

- **ALB-M1-R2** (env + launcher hardening) and **ALB-006** (session-state JSON engine) in parallel — disjoint scopes.

## Metrics notes

- Conductor session cost: 3 short GLM sessions (≈3 prompt-equivalents on the plan lane).
- The capture kit itself performed exactly as specified under real fire: hooks never blocked the observed session, even mid-failure.
