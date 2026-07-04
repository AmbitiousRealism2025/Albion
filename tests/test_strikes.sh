#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_DIR="${TMP_ROOT%/}/albion-test-strikes.$$"
HOOK_SCRIPT="${ROOT_DIR}/plugin/scripts/post-tool-strikes.sh"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

run_hook() {
  local name
  local payload
  local out_file
  local err_file
  local state_dir
  name="$1"
  payload="$2"
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"
  state_dir="${TMP_DIR}/${name}.state"
  mkdir -p "$state_dir"

  set +e
  printf '%s' "$payload" | ALBION_STATE_DIR="$state_dir" ALBION_STRIKES_LOG="${TMP_DIR}/${name}.log" bash "$HOOK_SCRIPT" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  RUN_STATE_DIR="$state_dir"
  RUN_LOG="${TMP_DIR}/${name}.log"
  set -e
}

run_hook_in_state() {
  local name
  local payload
  local state_dir
  local out_file
  local err_file
  name="$1"
  payload="$2"
  state_dir="$3"
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"
  mkdir -p "$state_dir"

  set +e
  printf '%s' "$payload" | ALBION_STATE_DIR="$state_dir" ALBION_STRIKES_LOG="${TMP_DIR}/${name}.log" bash "$HOOK_SCRIPT" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  RUN_STATE_DIR="$state_dir"
  RUN_LOG="${TMP_DIR}/${name}.log"
  set -e
}

state_get() {
  local state_dir
  local session_id
  local key
  local default_value
  state_dir="$1"
  session_id="$2"
  key="$3"
  default_value="$4"
  ALBION_STATE_DIR="$state_dir" "${ROOT_DIR}/state/albion-state" get --file "${state_dir}/${session_id}.json" --key "$key" --default "$default_value"
}

hook_context() {
  python3 -c '
import json
import sys

payload = json.loads(sys.argv[1])
print(payload["hookSpecificOutput"]["additionalContext"])
' "$1"
}

json_string_length() {
  python3 -c 'import sys; print(len(sys.argv[1]))' "$1"
}

file_failure_payload() {
  local session_id
  local tool_name
  local file_path
  session_id="$1"
  tool_name="$2"
  file_path="$3"
  python3 -c '
import json
import sys

print(json.dumps({
    "session_id": sys.argv[1],
    "hook_event_name": "PostToolUse",
    "tool_name": sys.argv[2],
    "tool_input": {"file_path": sys.argv[3]},
    "tool_response": {"is_error": True},
}, separators=(",", ":")))
' "$session_id" "$tool_name" "$file_path"
}

file_success_payload() {
  local session_id
  local tool_name
  local file_path
  session_id="$1"
  tool_name="$2"
  file_path="$3"
  python3 -c '
import json
import sys

print(json.dumps({
    "session_id": sys.argv[1],
    "hook_event_name": "PostToolUse",
    "tool_name": sys.argv[2],
    "tool_input": {"file_path": sys.argv[3]},
    "tool_response": {"success": True},
}, separators=(",", ":")))
' "$session_id" "$tool_name" "$file_path"
}

assert_no_state_files() {
  local state_dir
  local files
  state_dir="$1"
  files="$(find "$state_dir" -type f ! -name '*.lock' -print)"
  assert_eq "" "$files" "successful payloads do not create state files"
}

test_consecutive_failures_inject_at_second_and_third_strike() {
  local state_dir
  local payload
  local context
  local session_id
  local state_key
  session_id="strike-session-001"
  state_dir="${TMP_DIR}/consecutive.state"
  state_key="strikes.Edit__src_parser_ts"
  payload="$(file_failure_payload "$session_id" Edit "src/parser.ts")"

  run_hook_in_state "strike-1" "$payload" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "first strike exits zero"
  assert_eq "" "$RUN_STDOUT" "first strike is silent"
  assert_eq "1" "$(state_get "$state_dir" "$session_id" "$state_key" missing)" "first strike stores count 1"

  run_hook_in_state "strike-2" "$payload" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "second strike exits zero"
  context="$(hook_context "$RUN_STDOUT")"
  assert_contains "$context" "Strike 2 of 3 on Edit:src/parser.ts" "second strike injects factual count"
  assert_contains "$context" "the same change has now failed twice" "second strike explains repeated failure"
  assert_eq "2" "$(state_get "$state_dir" "$session_id" "$state_key" missing)" "second strike stores count 2"

  run_hook_in_state "strike-3" "$payload" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "third strike exits zero"
  context="$(hook_context "$RUN_STDOUT")"
  assert_contains "$context" "Strike 3 of 3 on Edit:src/parser.ts" "third strike injects factual count"
  assert_contains "$context" "counterexamples log" "third strike names the counterexample record"
  assert_contains "$context" "smallest falsifiable check" "third strike shrinks the next check"
  assert_contains "$context" "revert is the escalation" "third strike keeps revert as escalation"
  assert_eq "3" "$(state_get "$state_dir" "$session_id" "$state_key" missing)" "third strike stores count 3"
  if [ "$(json_string_length "$context")" -ge 500 ]; then
    assert_fail "strike context must stay under 500 characters"
  fi
}

test_success_resets_existing_counter() {
  local state_dir
  local session_id
  local state_key
  local failure_payload
  local success_payload
  session_id="strike-session-reset"
  state_dir="${TMP_DIR}/reset.state"
  state_key="strikes.Edit__src_parser_ts"
  failure_payload="$(file_failure_payload "$session_id" Edit "src/parser.ts")"
  success_payload="$(file_success_payload "$session_id" Edit "src/parser.ts")"

  run_hook_in_state "reset-fail-1" "$failure_payload" "$state_dir"
  run_hook_in_state "reset-fail-2" "$failure_payload" "$state_dir"
  assert_eq "2" "$(state_get "$state_dir" "$session_id" "$state_key" missing)" "precondition has count 2"

  run_hook_in_state "reset-success" "$success_payload" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "success exits zero"
  assert_eq "" "$RUN_STDOUT" "success emits no injection"
  assert_eq "missing" "$(state_get "$state_dir" "$session_id" "$state_key" missing)" "success deletes the strike key"
}

test_distinct_operations_keep_independent_counters() {
  local state_dir
  local session_id
  local first_payload
  local second_payload
  session_id="strike-session-independent"
  state_dir="${TMP_DIR}/independent.state"
  first_payload="$(file_failure_payload "$session_id" Edit "src/parser.ts")"
  second_payload="$(file_failure_payload "$session_id" Edit "src/lexer.ts")"

  run_hook_in_state "independent-first-1" "$first_payload" "$state_dir"
  run_hook_in_state "independent-first-2" "$first_payload" "$state_dir"
  assert_contains "$(hook_context "$RUN_STDOUT")" "Strike 2 of 3 on Edit:src/parser.ts" "first operation reaches strike 2"

  run_hook_in_state "independent-second-1" "$second_payload" "$state_dir"
  assert_eq "" "$RUN_STDOUT" "different operation starts at silent strike 1"
  assert_eq "2" "$(state_get "$state_dir" "$session_id" "strikes.Edit__src_parser_ts" missing)" "first operation remains at count 2"
  assert_eq "1" "$(state_get "$state_dir" "$session_id" "strikes.Edit__src_lexer_ts" missing)" "second operation has independent count 1"
}

test_bash_failure_detection_is_conservative() {
  local state_dir
  local session_id
  local failed_payload
  local ambiguous_payload
  session_id="strike-session-bash"
  state_dir="${TMP_DIR}/bash.state"
  failed_payload='{"session_id":"strike-session-bash","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"make test"},"tool_response":{"stderr":"failed\n","exit_code":2,"interrupted":false}}'
  ambiguous_payload='{"session_id":"strike-session-bash","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"make test"},"tool_response":{"stderr":"warning\n","interrupted":false}}'

  run_hook_in_state "bash-fail" "$failed_payload" "$state_dir"
  assert_eq "1" "$(state_get "$state_dir" "$session_id" "strikes.Bash__make" missing)" "bash stderr plus non-zero exit code counts as failure"

  run_hook_in_state "bash-ambiguous" "$ambiguous_payload" "$state_dir"
  assert_eq "" "$RUN_STDOUT" "ambiguous bash stderr emits no injection"
  assert_eq "missing" "$(state_get "$state_dir" "$session_id" "strikes.Bash__make" missing)" "ambiguous bash stderr is treated as success and resets"
}

test_captured_success_payloads_are_silent_and_do_not_pollute_state() {
  local state_dir
  local line
  local index
  state_dir="${TMP_DIR}/captured.state"
  index=0
  mkdir -p "$state_dir"

  while IFS= read -r line; do
    index=$((index + 1))
    run_hook_in_state "captured-${index}" "$line" "$state_dir"
    assert_exit_code 0 "$RUN_CODE" "captured success payload exits zero"
    assert_eq "" "$RUN_STDOUT" "captured success payload emits no injection"
    assert_eq "" "$RUN_STDERR" "captured success payload writes no stderr"
  done <"${ROOT_DIR}/tests/fixtures/hooks/captured/PostToolUse.jsonl"

  assert_no_state_files "$state_dir"
}

test_synthetic_success_fixture_is_silent() {
  local payload
  payload="$(cat "${ROOT_DIR}/tests/fixtures/hooks/synthetic/PostToolUse.jsonl")"

  run_hook "synthetic-success" "$payload"
  assert_exit_code 0 "$RUN_CODE" "synthetic success payload exits zero"
  assert_eq "" "$RUN_STDOUT" "synthetic success payload emits no injection"
  assert_no_state_files "$RUN_STATE_DIR"
}

test_malformed_stdin_exits_zero_and_logs_one_line() {
  run_hook "malformed" "{not json"
  assert_exit_code 0 "$RUN_CODE" "malformed stdin exits zero"
  assert_eq "" "$RUN_STDOUT" "malformed stdin stays stdout-silent"
  assert_eq "" "$RUN_STDERR" "malformed stdin stays stderr-silent"
  assert_file_exists "$RUN_LOG" "malformed stdin writes a log"
  assert_eq "1" "$(wc -l <"$RUN_LOG" | tr -d ' ')" "malformed stdin logs one line"
  assert_contains "$(cat "$RUN_LOG")" "invalid json" "malformed stdin log names invalid JSON"
}

test_consecutive_failures_inject_at_second_and_third_strike
test_success_resets_existing_counter
test_distinct_operations_keep_independent_counters
test_bash_failure_detection_is_conservative
test_captured_success_payloads_are_silent_and_do_not_pollute_state
test_synthetic_success_fixture_is_silent
test_malformed_stdin_exits_zero_and_logs_one_line
