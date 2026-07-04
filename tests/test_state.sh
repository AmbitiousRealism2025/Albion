#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_DIR="${TMP_ROOT%/}/albion-test-state.$$"
STATE_CLI="${ROOT_DIR}/state/albion-state"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

run_state() {
  local name
  local out_file
  local err_file

  name="$1"
  shift
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  "$STATE_CLI" "$@" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
}

test_state_crud_and_dotted_paths() {
  local state_file
  state_file="${TMP_DIR}/crud/session.json"

  run_state set-name set --file "$state_file" --key tasks.open --value 3
  assert_exit_code 0 "$RUN_CODE" "set creates a dotted path"
  assert_file_exists "$state_file" "set creates the state file"

  run_state get-open get --file "$state_file" --key tasks.open
  assert_exit_code 0 "$RUN_CODE" "get returns an existing dotted value"
  assert_eq "3" "$RUN_STDOUT" "get prints scalar values"

  run_state set-status set --file "$state_file" --key last_test --value '{"command":"bash tests/run.sh","status":"pass"}'
  assert_exit_code 0 "$RUN_CODE" "set stores JSON objects"
  run_state get-status get --file "$state_file" --key last_test
  assert_eq '{"command":"bash tests/run.sh","status":"pass"}' "$RUN_STDOUT" "get JSON-encodes objects compactly"

  run_state set-note set --file "$state_file" --key notes.latest --value not-json
  assert_exit_code 0 "$RUN_CODE" "set stores non-JSON values as strings"
  run_state get-note get --file "$state_file" --key notes.latest
  assert_eq "not-json" "$RUN_STDOUT" "get prints string values without JSON quotes"

  run_state del-note del --file "$state_file" --key notes.latest
  assert_exit_code 0 "$RUN_CODE" "del removes an existing value"
  run_state get-note-default get --file "$state_file" --key notes.latest --default fallback
  assert_eq "fallback" "$RUN_STDOUT" "get uses default after deletion"

  run_state del-missing del --file "$state_file" --key notes.latest
  assert_exit_code 0 "$RUN_CODE" "del is silent for missing values"
  assert_eq "" "$RUN_STDOUT" "del writes no stdout"
}

test_state_defaults_and_missing_keys() {
  local state_file
  state_file="${TMP_DIR}/missing/session.json"

  run_state get-default get --file "$state_file" --key tasks.open --default 0
  assert_exit_code 0 "$RUN_CODE" "get succeeds with default for a missing file"
  assert_eq "0" "$RUN_STDOUT" "get prints the supplied default"

  run_state get-missing get --file "$state_file" --key tasks.open
  assert_exit_code 1 "$RUN_CODE" "get exits 1 for a missing key without default"
  assert_contains "$RUN_STDERR" "tasks.open" "missing-key error names the key"

  run_state dump-empty dump --file "$state_file"
  assert_exit_code 0 "$RUN_CODE" "dump succeeds for a missing file"
  assert_eq "{}" "$RUN_STDOUT" "dump prints an empty object for a missing file"
}

test_state_incr_and_type_errors() {
  local state_file
  state_file="${TMP_DIR}/incr/session.json"

  run_state incr-default incr --file "$state_file" --key strikes.Bash
  assert_exit_code 0 "$RUN_CODE" "incr creates missing counters"
  assert_eq "1" "$RUN_STDOUT" "incr prints the new value"

  run_state incr-step incr --file "$state_file" --key strikes.Bash --value 4
  assert_exit_code 0 "$RUN_CODE" "incr accepts an explicit integer step"
  assert_eq "5" "$RUN_STDOUT" "incr adds the explicit step"

  run_state set-string set --file "$state_file" --key strikes.Read --value not-an-int
  assert_exit_code 0 "$RUN_CODE" "set prepares a non-integer counter"
  run_state incr-string incr --file "$state_file" --key strikes.Read
  assert_exit_code 1 "$RUN_CODE" "incr exits 1 for non-integer existing values"
  assert_contains "$RUN_STDERR" "strikes.Read" "incr error names the key"
}

test_state_corrupt_file_is_not_overwritten() {
  local state_file
  local before
  local after
  state_file="${TMP_DIR}/corrupt/session.json"
  mkdir -p "$(dirname "$state_file")"
  printf '{not json\n' >"$state_file"
  before="$(cat "$state_file")"

  run_state corrupt-set set --file "$state_file" --key tasks.open --value 1
  assert_exit_code 2 "$RUN_CODE" "corrupt state exits 2"
  assert_contains "$RUN_STDERR" "$state_file" "corrupt error names the file"
  assert_contains "$RUN_STDERR" "move it aside" "corrupt error names the remedy"
  after="$(cat "$state_file")"
  assert_eq "$before" "$after" "corrupt file is left untouched"
}

test_state_usage_and_file_mode() {
  local state_file
  local mode
  state_file="${TMP_DIR}/mode/session.json"

  run_state bad-verb nope --file "$state_file"
  assert_exit_code 64 "$RUN_CODE" "bad verb exits 64"
  assert_contains "$RUN_STDERR" "Usage:" "usage errors print usage text"

  run_state bad-flags get --file "$state_file"
  assert_exit_code 64 "$RUN_CODE" "missing key exits 64 for keyed operations"
  assert_contains "$RUN_STDERR" "Usage:" "missing flags print usage text"

  run_state mode-set set --file "$state_file" --key schema_version --value 1
  assert_exit_code 0 "$RUN_CODE" "set succeeds before mode check"
  mode="$(python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' "$state_file")"
  assert_eq "600" "$mode" "state files are created mode 0600"
}

test_state_concurrent_increments() {
  local state_file

  state_file="${TMP_DIR}/concurrent/session.json"

  for _ in $(seq 1 20); do
    "$STATE_CLI" incr --file "$state_file" --key strikes.Bash >/dev/null &
  done
  wait

  run_state get-concurrent get --file "$state_file" --key strikes.Bash
  assert_exit_code 0 "$RUN_CODE" "concurrent increments leave a readable counter"
  assert_eq "20" "$RUN_STDOUT" "20 parallel increments yield exactly 20"
}

test_state_wrapper_round_trip() {
  local session_id
  local state_file
  session_id="wrapper-session-001"

  # shellcheck source=state/state-lib.sh
  . "${ROOT_DIR}/state/state-lib.sh"

  ALBION_STATE_DIR="${TMP_DIR}/wrapper-state"
  state_file="$(albion_state_file "$session_id")"
  assert_eq "${ALBION_STATE_DIR}/${session_id}.json" "$state_file" "wrapper resolves state path from ALBION_STATE_DIR"

  albion_state_set "$session_id" tasks.open 2 >/dev/null
  assert_eq "2" "$(albion_state_get "$session_id" tasks.open)" "wrapper set/get round-trip"
  assert_eq "3" "$(albion_state_incr "$session_id" tasks.open)" "wrapper incr round-trip"
  albion_state_del "$session_id" tasks.open >/dev/null
  assert_eq "0" "$(albion_state_get "$session_id" tasks.open 0)" "wrapper get default round-trip"
  assert_eq "{}" "$(albion_state_dump missing-wrapper-session)" "wrapper dump handles missing state"
}

test_state_crud_and_dotted_paths
test_state_defaults_and_missing_keys
test_state_incr_and_type_errors
test_state_corrupt_file_is_not_overwritten
test_state_usage_and_file_mode
test_state_concurrent_increments
test_state_wrapper_round_trip
