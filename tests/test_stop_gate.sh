#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_DIR="${TMP_ROOT%/}/albion-test-stop-gate.$$"
HOOK_SCRIPT="${ROOT_DIR}/plugin/scripts/stop-gate.sh"
STATE_CLI="${ROOT_DIR}/state/albion-state"

# shellcheck disable=SC1091
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

run_gate_in_state() {
  local name
  local payload
  local state_dir
  local workbench_root
  local out_file
  local err_file
  name="$1"
  payload="$2"
  state_dir="$3"
  workbench_root="$4"
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"
  mkdir -p "$state_dir" "$workbench_root"

  set +e
  printf '%s' "$payload" | ALBION_STATE_DIR="$state_dir" ALBION_WORKBENCH_ROOT="$workbench_root" ALBION_GATE_LOG="${TMP_DIR}/${name}.log" bash "$HOOK_SCRIPT" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  RUN_LOG="${TMP_DIR}/${name}.log"
  set -e
}

run_gate() {
  local name
  local payload
  name="$1"
  payload="$2"
  run_gate_in_state "$name" "$payload" "${TMP_DIR}/${name}.state" "${TMP_DIR}/${name}.workbench"
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

  ALBION_STATE_DIR="$state_dir" "$STATE_CLI" set --file "${state_dir}/${session_id}.json" --key "$key" --value "$value" >/dev/null
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

  ALBION_STATE_DIR="$state_dir" "$STATE_CLI" get --file "${state_dir}/${session_id}.json" --key "$key" --default "$default_value"
}

payload_json() {
  local session_id
  local stop_hook_active
  local last_message
  local background_count
  local cron_count
  session_id="$1"
  stop_hook_active="$2"
  last_message="${3:-}"
  background_count="${4:-0}"
  cron_count="${5:-0}"

  python3 - "$session_id" "$stop_hook_active" "$last_message" "$background_count" "$cron_count" <<'PY'
import json
import sys

session_id = sys.argv[1]
stop_hook_active = sys.argv[2] == "true"
last_message = sys.argv[3]
background_count = int(sys.argv[4])
cron_count = int(sys.argv[5])

payload = {
    "session_id": session_id,
    "hook_event_name": "Stop",
    "stop_hook_active": stop_hook_active,
    "last_assistant_message": last_message,
    "background_tasks": [
        {"id": f"bg-{index}", "type": "shell", "status": "running", "description": "test"}
        for index in range(background_count)
    ],
    "session_crons": [
        {"id": f"cron-{index}", "schedule": "* * * * *", "recurring": True, "prompt": "test"}
        for index in range(cron_count)
    ],
}
print(json.dumps(payload, separators=(",", ":")))
PY
}

block_reason() {
  python3 -c '
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["decision"] == "block"
reason = payload["reason"]
assert isinstance(reason, str)
assert reason.strip()
print(reason)
' "$1"
}

assert_valid_block_json() {
  local output
  local reason
  output="$1"

  reason="$(block_reason "$output")"
  if [ "$reason" = "" ]; then
    assert_fail "block payload reason should not be empty"
  fi
}

make_workbench_task() {
  local workbench_root
  local task_name
  local task_text
  local verification_text
  workbench_root="$1"
  task_name="$2"
  task_text="$3"
  verification_text="${4-__missing__}"

  mkdir -p "$workbench_root/fable-mode/$task_name"
  printf '%s\n' "$task_text" >"$workbench_root/fable-mode/$task_name/task.md"
  if [ "$verification_text" != "__missing__" ]; then
    printf '%s\n' "$verification_text" >"$workbench_root/fable-mode/$task_name/verification.md"
  fi
}

test_open_tasks_block_names_count() {
  local session_id
  local state_dir
  local payload
  local reason
  session_id="stop-open-tasks"
  state_dir="${TMP_DIR}/open.state"
  payload="$(payload_json "$session_id" false "Stopping now.")"
  state_set "$state_dir" "$session_id" tasks.open 2

  run_gate_in_state "open-tasks" "$payload" "$state_dir" "${TMP_DIR}/open.workbench"
  assert_exit_code 0 "$RUN_CODE" "open tasks gate exits zero"
  assert_valid_block_json "$RUN_STDOUT"
  reason="$(block_reason "$RUN_STDOUT")"
  assert_contains "$reason" "2 open tasks" "open tasks reason names the count"
  assert_eq "1" "$(state_get "$state_dir" "$session_id" gate.blocks missing)" "block increments gate.blocks"
}

test_failed_last_test_block_names_command() {
  local session_id
  local state_dir
  local payload
  local reason
  session_id="stop-failed-test"
  state_dir="${TMP_DIR}/failed-test.state"
  payload="$(payload_json "$session_id" false "Tests are still being checked.")"
  state_set "$state_dir" "$session_id" last_test '{"command":"bash tests/run.sh","status":"fail"}'

  run_gate_in_state "failed-test" "$payload" "$state_dir" "${TMP_DIR}/failed-test.workbench"
  assert_exit_code 0 "$RUN_CODE" "failed test gate exits zero"
  assert_valid_block_json "$RUN_STDOUT"
  reason="$(block_reason "$RUN_STDOUT")"
  assert_contains "$reason" "last test run failed: \`bash tests/run.sh\`" "failed test reason names the command"
}

test_empty_verification_on_nontrivial_workbench_task_blocks() {
  local session_id
  local state_dir
  local workbench_root
  local payload
  local reason
  session_id="stop-empty-verification"
  state_dir="${TMP_DIR}/empty-verification.state"
  workbench_root="${TMP_DIR}/empty-verification.workbench"
  payload="$(payload_json "$session_id" false "The implementation is in progress.")"
  make_workbench_task "$workbench_root" active-task "Implement the multi-file hook and verify it."

  run_gate_in_state "empty-verification" "$payload" "$state_dir" "$workbench_root"
  assert_exit_code 0 "$RUN_CODE" "empty verification gate exits zero"
  assert_valid_block_json "$RUN_STDOUT"
  reason="$(block_reason "$RUN_STDOUT")"
  assert_contains "$reason" "verification.md missing or empty for workbench task \`active-task\`" "empty verification reason names the task"
}

test_all_clear_allows_and_resets_counter() {
  local session_id
  local state_dir
  local workbench_root
  local payload
  session_id="stop-all-clear"
  state_dir="${TMP_DIR}/all-clear.state"
  workbench_root="${TMP_DIR}/all-clear.workbench"
  payload="$(payload_json "$session_id" false "Finished with evidence.")"
  state_set "$state_dir" "$session_id" gate.blocks 2
  state_set "$state_dir" "$session_id" tasks.open 0
  state_set "$state_dir" "$session_id" last_test '{"command":"bash tests/run.sh","status":"pass"}'
  make_workbench_task "$workbench_root" clear-task "Implement the hook." "bash tests/run.sh passed"

  run_gate_in_state "all-clear" "$payload" "$state_dir" "$workbench_root"
  assert_exit_code 0 "$RUN_CODE" "all clear exits zero"
  assert_eq "" "$RUN_STDOUT" "all clear emits no stdout"
  assert_eq "" "$RUN_STDERR" "all clear emits no stderr"
  assert_eq "0" "$(state_get "$state_dir" "$session_id" gate.blocks missing)" "all clear resets gate.blocks"
}

test_stop_hook_active_allows_soft_signal() {
  local session_id
  local state_dir
  local workbench_root
  local payload
  session_id="stop-active-soft"
  state_dir="${TMP_DIR}/active-soft.state"
  workbench_root="${TMP_DIR}/active-soft.workbench"
  payload="$(payload_json "$session_id" true "Done.")"
  state_set "$state_dir" "$session_id" last_test '{"command":"bash tests/run.sh","status":"fail"}'
  make_workbench_task "$workbench_root" active-soft-task "Implement the hook."

  run_gate_in_state "active-soft" "$payload" "$state_dir" "$workbench_root"
  assert_exit_code 0 "$RUN_CODE" "active stop with soft signal exits zero"
  assert_eq "" "$RUN_STDOUT" "active stop with only soft signals allows"
}

test_stop_hook_active_still_blocks_open_tasks() {
  local session_id
  local state_dir
  local payload
  local reason
  session_id="stop-active-open"
  state_dir="${TMP_DIR}/active-open.state"
  payload="$(payload_json "$session_id" true "Continuing from the Stop hook.")"
  state_set "$state_dir" "$session_id" tasks.open 1
  state_set "$state_dir" "$session_id" last_test '{"command":"bash tests/run.sh","status":"fail"}'

  run_gate_in_state "active-open" "$payload" "$state_dir" "${TMP_DIR}/active-open.workbench"
  assert_exit_code 0 "$RUN_CODE" "active stop with open tasks exits zero"
  assert_valid_block_json "$RUN_STDOUT"
  reason="$(block_reason "$RUN_STDOUT")"
  assert_contains "$reason" "1 open task" "active stop still blocks on open tasks"
  case "$reason" in
    *"last test run failed"*) assert_fail "active stop should not block on soft failed-test signal" ;;
  esac
}

test_background_tasks_allow_despite_open_tasks() {
  local session_id
  local state_dir
  local payload
  session_id="stop-background"
  state_dir="${TMP_DIR}/background.state"
  payload="$(payload_json "$session_id" false "Still running background work." 1)"
  state_set "$state_dir" "$session_id" tasks.open 4

  run_gate_in_state "background" "$payload" "$state_dir" "${TMP_DIR}/background.workbench"
  assert_exit_code 0 "$RUN_CODE" "background tasks exit zero"
  assert_eq "" "$RUN_STDOUT" "background tasks allow despite open tasks"
  assert_eq "" "$RUN_STDERR" "background tasks emit no stderr"
}

test_block_counter_yields_after_three_blocks() {
  local session_id
  local state_dir
  local payload
  session_id="stop-counter-cap"
  state_dir="${TMP_DIR}/counter-cap.state"
  payload="$(payload_json "$session_id" false "Done.")"
  state_set "$state_dir" "$session_id" tasks.open 1
  state_set "$state_dir" "$session_id" gate.blocks 3

  run_gate_in_state "counter-cap" "$payload" "$state_dir" "${TMP_DIR}/counter-cap.workbench"
  assert_exit_code 0 "$RUN_CODE" "counter cap exits zero"
  assert_eq "" "$RUN_STDOUT" "counter cap allows instead of blocking"
  assert_contains "$RUN_STDERR" "yielded after 3 consecutive blocks" "counter cap emits factual stderr notice"
  assert_eq "3" "$(state_get "$state_dir" "$session_id" gate.blocks missing)" "counter cap does not increment beyond 3"
}

test_malformed_stdin_exits_zero() {
  run_gate "malformed" "{not json"
  assert_exit_code 0 "$RUN_CODE" "malformed stdin exits zero"
  assert_eq "" "$RUN_STDOUT" "malformed stdin emits no stdout"
  assert_eq "" "$RUN_STDERR" "malformed stdin emits no stderr"
  assert_file_exists "$RUN_LOG" "malformed stdin is logged"
  assert_contains "$(cat "$RUN_LOG")" "invalid json" "malformed log names invalid JSON"
}

test_completion_claim_strengthens_state_based_reason_only() {
  local session_id
  local state_dir
  local payload
  local reason
  session_id="stop-claim"
  state_dir="${TMP_DIR}/claim.state"
  payload="$(payload_json "$session_id" false "Done, all tests pass.")"

  run_gate_in_state "claim-alone" "$payload" "$state_dir" "${TMP_DIR}/claim-alone.workbench"
  assert_exit_code 0 "$RUN_CODE" "claim alone exits zero"
  assert_eq "" "$RUN_STDOUT" "claim alone does not block"

  state_set "$state_dir" "$session_id" last_test '{"command":"bash tests/run.sh","status":"fail"}'
  run_gate_in_state "claim-failed-test" "$payload" "$state_dir" "${TMP_DIR}/claim-failed-test.workbench"
  assert_valid_block_json "$RUN_STDOUT"
  reason="$(block_reason "$RUN_STDOUT")"
  assert_contains "$reason" "last test run failed" "claim with failed test includes state reason"
  assert_contains "$reason" "claimed completion" "claim with failed test adds contradiction reason"
}

test_captured_payloads_allow_with_empty_state() {
  local payload
  local index
  index=0

  while IFS= read -r payload; do
    run_gate "captured-${index}" "$payload"
    assert_exit_code 0 "$RUN_CODE" "captured Stop payload ${index} exits zero"
    assert_eq "" "$RUN_STDOUT" "captured Stop payload ${index} allows with empty state"
    index=$((index + 1))
  done <"${ROOT_DIR}/tests/fixtures/hooks/captured/Stop.jsonl"
  assert_eq "2" "$index" "all captured Stop payloads were exercised"
}

test_hook_script_exists() {
  assert_file_exists "$HOOK_SCRIPT" "Stop gate script should exist"
}

test_hook_script_exists
test_open_tasks_block_names_count
test_failed_last_test_block_names_command
test_empty_verification_on_nontrivial_workbench_task_blocks
test_all_clear_allows_and_resets_counter
test_stop_hook_active_allows_soft_signal
test_stop_hook_active_still_blocks_open_tasks
test_background_tasks_allow_despite_open_tasks
test_block_counter_yields_after_three_blocks
test_malformed_stdin_exits_zero
test_completion_claim_strengthens_state_based_reason_only
test_captured_payloads_allow_with_empty_state
