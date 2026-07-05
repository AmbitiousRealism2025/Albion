#!/usr/bin/env bash
set -euo pipefail

# These tests exercise the hooks' ACTIVE behavior (as if launched by bin/albion).
export ALBION_ACTIVE=1

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

state_set() {
  local state_dir
  local session_id
  local key
  local value
  state_dir="$1"
  session_id="$2"
  key="$3"
  value="$4"
  ALBION_STATE_DIR="$state_dir" "${ROOT_DIR}/state/albion-state" set --file "${state_dir}/${session_id}.json" --key "$key" --value "$value"
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

bash_payload() {
  local session_id
  local command
  local exit_code
  local stderr
  session_id="$1"
  command="$2"
  exit_code="$3"
  stderr="$4"
  python3 -c '
import json
import sys

print(json.dumps({
    "session_id": sys.argv[1],
    "hook_event_name": "PostToolUse",
    "tool_name": "Bash",
    "tool_input": {"command": sys.argv[2]},
    "tool_response": {
        "stdout": "ok\n" if sys.argv[3] == "0" else "",
        "stderr": sys.argv[4],
        "exit_code": int(sys.argv[3]),
        "interrupted": False,
    },
}, separators=(",", ":")))
' "$session_id" "$command" "$exit_code" "$stderr"
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

test_passing_tests_run_records_last_test_pass() {
  local state_dir
  local session_id
  local payload
  session_id="strike-session-last-test-pass"
  state_dir="${TMP_DIR}/last-test-pass.state"
  payload="$(bash_payload "$session_id" "bash tests/run.sh" 0 "")"

  run_hook_in_state "last-test-pass" "$payload" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "passing test payload exits zero"
  assert_eq "" "$RUN_STDOUT" "passing test payload emits no injection"
  assert_eq "pass" "$(state_get "$state_dir" "$session_id" last_test.status missing)" "passing test records pass"
  assert_eq "bash tests/run.sh" "$(state_get "$state_dir" "$session_id" last_test.command missing)" "passing test records command"
}

test_failing_run_tests_py_records_last_test_fail() {
  local state_dir
  local session_id
  local payload
  session_id="strike-session-last-test-fail"
  state_dir="${TMP_DIR}/last-test-fail.state"
  payload="$(bash_payload "$session_id" "python3 tests/run_tests.py" 1 "failed\n")"

  run_hook_in_state "last-test-fail" "$payload" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "failing test payload exits zero"
  assert_eq "fail" "$(state_get "$state_dir" "$session_id" last_test.status missing)" "failing test records fail"
  assert_eq "python3 tests/run_tests.py" "$(state_get "$state_dir" "$session_id" last_test.command missing)" "failing test records command"
  assert_eq "1" "$(state_get "$state_dir" "$session_id" strikes.Bash__python3 missing)" "failing test still records strike"
}

test_module_form_unittest_records_last_test() {
  local state_dir
  local session_id
  local payload
  session_id="strike-session-last-test-module"
  state_dir="${TMP_DIR}/last-test-module.state"
  payload="$(bash_payload "$session_id" "python -m unittest tests.test_report -v" 0 "OK\n")"

  run_hook_in_state "last-test-module" "$payload" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "module-form test payload exits zero"
  assert_eq "pass" "$(state_get "$state_dir" "$session_id" last_test.status missing)" "python -m unittest records pass"
  assert_eq "python -m unittest tests.test_report -v" "$(state_get "$state_dir" "$session_id" last_test.command missing)" "module-form records command"
}

test_failing_non_test_command_leaves_last_test_untouched() {
  local state_dir
  local session_id
  local payload
  session_id="strike-session-last-test-untouched"
  state_dir="${TMP_DIR}/last-test-untouched.state"
  state_set "$state_dir" "$session_id" last_test '{"command":"bash tests/run.sh","status":"pass","at":"2026-07-04T12:00:00Z"}'
  payload="$(bash_payload "$session_id" "ls /nope" 2 "ls: /nope: No such file or directory\n")"

  run_hook_in_state "last-test-untouched" "$payload" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "failing non-test exits zero"
  assert_eq "1" "$(state_get "$state_dir" "$session_id" strikes.Bash__ls missing)" "failing non-test still records strike"
  assert_eq "pass" "$(state_get "$state_dir" "$session_id" last_test.status missing)" "failing non-test does not change status"
  assert_eq "bash tests/run.sh" "$(state_get "$state_dir" "$session_id" last_test.command missing)" "failing non-test does not change command"
}

test_last_test_overwrites_prior_failure_with_pass() {
  local state_dir
  local session_id
  local fail_payload
  local pass_payload
  session_id="strike-session-last-test-overwrite"
  state_dir="${TMP_DIR}/last-test-overwrite.state"
  fail_payload="$(bash_payload "$session_id" "python3 tests/run_tests.py" 1 "failed\n")"
  pass_payload="$(bash_payload "$session_id" "bash tests/run.sh" 0 "")"

  run_hook_in_state "last-test-overwrite-fail" "$fail_payload" "$state_dir"
  assert_eq "fail" "$(state_get "$state_dir" "$session_id" last_test.status missing)" "precondition records fail"

  run_hook_in_state "last-test-overwrite-pass" "$pass_payload" "$state_dir"
  assert_eq "pass" "$(state_get "$state_dir" "$session_id" last_test.status missing)" "later passing test overwrites status"
  assert_eq "bash tests/run.sh" "$(state_get "$state_dir" "$session_id" last_test.command missing)" "later passing test overwrites command"
}

test_last_test_command_is_truncated_to_200_chars() {
  local state_dir
  local session_id
  local long_command
  local expected_command
  local payload
  session_id="strike-session-last-test-truncated"
  state_dir="${TMP_DIR}/last-test-truncated.state"
  long_command="pytest $(printf 'a%.0s' {1..250})"
  expected_command="${long_command:0:200}"
  payload="$(bash_payload "$session_id" "$long_command" 0 "")"

  run_hook_in_state "last-test-truncated" "$payload" "$state_dir"
  assert_eq "200" "$(json_string_length "$(state_get "$state_dir" "$session_id" last_test.command missing)")" "stored test command is capped at 200 chars"
  assert_eq "$expected_command" "$(state_get "$state_dir" "$session_id" last_test.command missing)" "stored test command is the first 200 chars"
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
test_passing_tests_run_records_last_test_pass
test_failing_run_tests_py_records_last_test_fail
test_module_form_unittest_records_last_test
test_failing_non_test_command_leaves_last_test_untouched
test_last_test_overwrites_prior_failure_with_pass
test_last_test_command_is_truncated_to_200_chars
test_captured_success_payloads_are_silent_and_do_not_pollute_state
test_synthetic_success_fixture_is_silent
test_malformed_stdin_exits_zero_and_logs_one_line
