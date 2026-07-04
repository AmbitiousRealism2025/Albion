# Work Packet ALB-M1-R2 — Harden env + launcher from First-Real-Workload Findings

## 1. TASK

Fix two defects surfaced by Albion's first real workload (the M2 capture session, build log 005): the env script clobbers deliberate overrides, and the launcher is defeated by a user-level pinned model ID.

## 2. EXPECTED OUTCOME

- `env/albion-env.sh` and `bin/albion` updated; `tests/test_env.sh` and `tests/test_launcher.sh` extended.

## 3. CONTEXT

- **Read first:** `CONVENTIONS.md`, current `env/albion-env.sh`, `bin/albion`, both test files.
- **Finding 1 (observed):** the env script unconditionally exports the hardening/tuning group, so a caller exporting `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=0` before launch gets silently reset to 1. Additionally, `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` makes headless Claude Code **force permission mode to default** (observed warning: "Permission mode forced to default — CLAUDE_CODE_SUBPROCESS_ENV_SCRUB is set"), which breaks `--permission-mode acceptEdits` — the mode every conductor dispatch and scripted workflow relies on.
- **Finding 2 (observed):** a user-level `~/.claude/settings.json` pinning `"model": "claude-fable-5[1m]"` bypasses the `ANTHROPIC_DEFAULT_*_MODEL` slot mapping entirely; the pinned ID reaches Z.ai verbatim → `400 [1211] Unknown Model` and the session dies. Explicit `--model 'glm-5.2[1m]'` on the CLI was verified working (suffix handled client-side, session completed).

## 4. MUST DO

**Env script:**
- Split exports into two groups with distinct semantics, documented in the header comment:
  - *Core routing* (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, the three model slots): unchanged semantics (hard set; model slots respect `ALBION_ALLOW_OVERRIDES=1`).
  - *Tuning/hardening* (`API_TIMEOUT_MS`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, `CLAUDE_CODE_ATTRIBUTION_HEADER`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`): export-if-unset (respect any pre-set value).
- Change the `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` default from 1 to **0**, with a header-comment note: default off because =1 forces headless permission mode to default (breaking scripted `acceptEdits` workflows); revisit as opt-in hardening in M6.
**Launcher:**
- In default and `--vanilla` modes, inject `--model "${ALBION_MODEL:-glm-5.2[1m]}"` into the claude argv — UNLESS the passthrough args already contain `--model` (user override wins).
- `--dry-run` output gains a `model=` line showing the resolved value.
**Tests:**
- Env: pre-set tuning var survives sourcing; unset tuning var gets the default; scrub default is 0; core routing still hard-sets.
- Launcher: stub-claude argv contains `--model glm-5.2[1m]` by default; user-supplied `--model foo` suppresses injection; `ALBION_MODEL=bar` changes it; dry-run shows `model=`.

## 5. MUST NOT DO

- Do NOT change core-routing semantics, failure messages, or exit codes beyond what's specified.
- Do NOT print token values anywhere.
- Do NOT modify files outside `env/albion-env.sh`, `bin/albion`, `tests/test_env.sh`, `tests/test_launcher.sh`.
- Do NOT run git state-changing commands.

## 6. TOOLS ALLOWED

File creation/editing and shell execution within the repository workspace only.

## 7. SUCCESS CRITERIA

- [ ] `bash tests/run.sh` exits 0 with extended coverage.
- [ ] `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=0` (or any pre-set tuning value) survives sourcing; unset gets documented defaults.
- [ ] Default-mode dry-run shows `model=glm-5.2[1m]`; with `--model x` passthrough, no injection.
- [ ] `git status` shows changes only in the four named files.
