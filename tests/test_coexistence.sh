#!/usr/bin/env bash
set -euo pipefail

# Coexistence guarantee: with no ALBION_ACTIVE marker (i.e. a stock Claude Code
# session, or `albion --vanilla`), every Albion hook must be a completely silent
# no-op — exit 0, no stdout — even on payloads that WOULD trigger action in an
# active Albion session. This is what lets the plugin be enabled globally and
# still coexist with stock Claude Code without interfering.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="${ROOT_DIR}/plugin/scripts"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

# Invoke a hook with the marker explicitly stripped, regardless of ambient env.
run_inert() {
  local hook="$1"
  local payload="$2"
  set +e
  RUN_OUT="$(printf '%s' "$payload" | env -u ALBION_ACTIVE bash "${SCRIPTS}/${hook}" 2>/dev/null)"
  RUN_CODE=$?
  set -e
}

assert_inert() {
  local hook="$1"
  local payload="$2"
  run_inert "$hook" "$payload"
  assert_exit_code 0 "$RUN_CODE" "${hook} exits 0 without ALBION_ACTIVE"
  assert_eq "" "$RUN_OUT" "${hook} emits nothing without ALBION_ACTIVE"
}

# Payloads that WOULD trigger each hook if it were active.
assert_inert "pre-tool-guard.sh" \
  '{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

assert_inert "post-tool-strikes.sh" \
  '{"session_id":"s","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"a.ts"},"tool_response":{"is_error":true}}'

assert_inert "workbench-scrubber.sh" \
  '{"session_id":"s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":".agent-workbench/x","content":"AKIAIOSFODNN7EXAMPLE"}}'

assert_inert "stop-gate.sh" \
  '{"session_id":"s","hook_event_name":"Stop","stop_hook_active":false}'

assert_inert "session-start-inject.sh" \
  '{"session_id":"s","hook_event_name":"SessionStart","source":"startup"}'

assert_inert "image-read-intercept.sh" \
  '{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/x.png"}}'
