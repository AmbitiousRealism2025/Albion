#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/albion-completion-manifest.XXXXXX")"
HOOK_SCRIPT="${ROOT_DIR}/plugin/scripts/stop-gate.sh"
STATE_CLI="${ROOT_DIR}/state/albion-state"

# shellcheck disable=SC1091
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  chmod -R u+w "$TMP_DIR" 2>/dev/null || true
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

payload_json() {
  local session_id
  session_id="$1"

  python3 - "$session_id" <<'PY'
import json
import sys

print(json.dumps({
    "session_id": sys.argv[1],
    "hook_event_name": "Stop",
    "stop_hook_active": False,
    "last_assistant_message": "Finished with evidence.",
    "background_tasks": [],
    "session_crons": [],
}, separators=(",", ":")))
PY
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

make_workbench_task() {
  local workbench_root
  local task_name
  local task_text
  local verification_text
  workbench_root="$1"
  task_name="$2"
  task_text="$3"
  verification_text="$4"

  mkdir -p "${workbench_root}/fable-mode/${task_name}"
  printf '%s\n' "$task_text" >"${workbench_root}/fable-mode/${task_name}/task.md"
  printf '%s\n' "$verification_text" >"${workbench_root}/fable-mode/${task_name}/verification.md"
}

run_gate() {
  local name
  local session_id
  local state_dir
  local workbench_root
  local manifest_path
  local out_file
  local err_file
  name="$1"
  session_id="$2"
  state_dir="$3"
  workbench_root="$4"
  manifest_path="$5"
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"
  mkdir -p "$state_dir" "$workbench_root"

  set +e
  printf '%s' "$(payload_json "$session_id")" | \
    ALBION_STATE_DIR="$state_dir" \
    ALBION_WORKBENCH_ROOT="$workbench_root" \
    ALBION_MANIFEST_PATH="$manifest_path" \
    ALBION_GATE_LOG="${TMP_DIR}/${name}.log" \
    bash "$HOOK_SCRIPT" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  RUN_LOG="${TMP_DIR}/${name}.log"
  set -e
}

manifest_field() {
  local manifest_path
  local field_path
  manifest_path="$1"
  field_path="$2"

  python3 - "$manifest_path" "$field_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    value = json.load(handle)
for part in sys.argv[2].split("."):
    if part.isdigit():
        value = value[int(part)]
    else:
        value = value[part]
print(value)
PY
}

assert_valid_manifest_json() {
  local manifest_path
  manifest_path="$1"

  python3 - "$manifest_path" <<'PY'
import json
import sys

with open(sys.argv[1], "rb") as handle:
    raw = handle.read()
assert raw.endswith(b"\n"), "manifest should end with newline"
json.loads(raw.decode("utf-8"))
PY
}

seed_allow_state() {
  local state_dir
  local session_id
  local workbench_root
  state_dir="$1"
  session_id="$2"
  workbench_root="$3"

  state_set "$state_dir" "$session_id" tasks.open 0
  state_set "$state_dir" "$session_id" last_test '{"command":"bash tests/run.sh","status":"pass"}'
  make_workbench_task "$workbench_root" seeded-task "Implement manifest protocol." "bash tests/run.sh passed"
}

test_allow_stop_writes_manifest() {
  local session_id
  local state_dir
  local workbench_root
  local manifest_path
  session_id="manifest-allow"
  state_dir="${TMP_DIR}/allow.state"
  workbench_root="${TMP_DIR}/allow.workbench"
  manifest_path="${TMP_DIR}/allow/completion-manifest.json"
  seed_allow_state "$state_dir" "$session_id" "$workbench_root"

  run_gate "allow" "$session_id" "$state_dir" "$workbench_root" "$manifest_path"
  assert_exit_code 0 "$RUN_CODE" "allow stop exits zero"
  assert_eq "" "$RUN_STDOUT" "allow stop emits no stdout"
  assert_eq "" "$RUN_STDERR" "allow stop emits no stderr"
  assert_file_exists "$manifest_path" "allow stop writes manifest"
  assert_valid_manifest_json "$manifest_path"
  assert_eq "albion-completion-manifest/v1" "$(manifest_field "$manifest_path" schema)" "manifest schema"
  assert_eq "complete" "$(manifest_field "$manifest_path" status)" "manifest status"
  assert_eq "$session_id" "$(manifest_field "$manifest_path" session_id)" "manifest session id"
  assert_eq "pass" "$(manifest_field "$manifest_path" last_test)" "manifest last test"
  assert_eq "0" "$(manifest_field "$manifest_path" open_task_count)" "manifest open task count"
  assert_eq "seeded-task" "$(manifest_field "$manifest_path" workbench_tasks.0.slug)" "manifest task slug"
  assert_eq "True" "$(manifest_field "$manifest_path" workbench_tasks.0.verification_present)" "manifest task verification"
}

test_blocked_stop_writes_no_manifest() {
  local session_id
  local state_dir
  local workbench_root
  local manifest_path
  session_id="manifest-blocked"
  state_dir="${TMP_DIR}/blocked.state"
  workbench_root="${TMP_DIR}/blocked.workbench"
  manifest_path="${TMP_DIR}/blocked/completion-manifest.json"
  state_set "$state_dir" "$session_id" tasks.open 1

  run_gate "blocked" "$session_id" "$state_dir" "$workbench_root" "$manifest_path"
  assert_exit_code 0 "$RUN_CODE" "blocked stop exits zero"
  assert_contains "$RUN_STDOUT" "\"decision\":\"block\"" "blocked stop emits block decision"
  if [ -e "$manifest_path" ]; then
    assert_fail "blocked stop should not write manifest"
  fi
}

test_manifest_write_failure_is_fail_open() {
  local session_id
  local state_dir
  local workbench_root
  local manifest_dir
  local manifest_path
  session_id="manifest-fail-open"
  state_dir="${TMP_DIR}/fail-open.state"
  workbench_root="${TMP_DIR}/fail-open.workbench"
  manifest_dir="${TMP_DIR}/unwritable"
  manifest_path="${manifest_dir}/completion-manifest.json"
  seed_allow_state "$state_dir" "$session_id" "$workbench_root"
  mkdir -p "$manifest_dir"
  chmod 500 "$manifest_dir"

  run_gate "fail-open" "$session_id" "$state_dir" "$workbench_root" "$manifest_path"
  chmod 700 "$manifest_dir"
  assert_exit_code 0 "$RUN_CODE" "manifest write failure exits zero"
  assert_eq "" "$RUN_STDOUT" "manifest write failure emits no stdout"
  assert_eq "" "$RUN_STDERR" "manifest write failure emits no stderr"
  assert_contains "$(cat "$RUN_LOG")" "failed to write completion manifest" "manifest write failure is logged"
}

test_repeated_allow_overwrites_with_fresh_timestamp() {
  local first_session
  local second_session
  local first_state_dir
  local second_state_dir
  local workbench_root
  local manifest_path
  local first_written_at
  local second_written_at
  first_session="manifest-first"
  second_session="manifest-second"
  first_state_dir="${TMP_DIR}/first.state"
  second_state_dir="${TMP_DIR}/second.state"
  workbench_root="${TMP_DIR}/overwrite.workbench"
  manifest_path="${TMP_DIR}/overwrite/completion-manifest.json"
  seed_allow_state "$first_state_dir" "$first_session" "$workbench_root"
  seed_allow_state "$second_state_dir" "$second_session" "$workbench_root"

  run_gate "overwrite-first" "$first_session" "$first_state_dir" "$workbench_root" "$manifest_path"
  assert_exit_code 0 "$RUN_CODE" "first allow exits zero"
  assert_valid_manifest_json "$manifest_path"
  first_written_at="$(manifest_field "$manifest_path" written_at)"
  sleep 1
  run_gate "overwrite-second" "$second_session" "$second_state_dir" "$workbench_root" "$manifest_path"
  assert_exit_code 0 "$RUN_CODE" "second allow exits zero"
  assert_valid_manifest_json "$manifest_path"
  second_written_at="$(manifest_field "$manifest_path" written_at)"
  assert_eq "$second_session" "$(manifest_field "$manifest_path" session_id)" "second allow overwrites session id"
  if [ "$first_written_at" = "$second_written_at" ]; then
    assert_fail "second allow should refresh written_at"
  fi
}

test_allow_stop_writes_manifest
test_blocked_stop_writes_no_manifest
test_manifest_write_failure_is_fail_open
test_repeated_allow_overwrites_with_fresh_timestamp
