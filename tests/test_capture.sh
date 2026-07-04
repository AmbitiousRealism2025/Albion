#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-capture.$$"
CAPTURE_SCRIPT="${ROOT_DIR}/tests/tools/capture/capture-hook-event.sh"
VALIDATOR_SCRIPT="${ROOT_DIR}/tests/tools/capture/validate-fixtures.sh"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$TMP_DIR"

test_capture_compacts_valid_payload() {
  local fixtures_dir
  local output
  local actual_code
  local actual_line
  local payload
  fixtures_dir="${TMP_DIR}/captured"
  payload='{
    "session_id": "capture-session-001",
    "transcript_path": "/Users/example/.claude/projects/scratch/capture-session-001.jsonl",
    "cwd": "/Users/example/src/scratch",
    "hook_event_name": "PreToolUse",
    "tool_name": "Bash",
    "tool_input": {
      "command": "printf '\''capture probe\\n'\''"
    }
  }'

  set +e
  output="$(printf '%s' "$payload" | ALBION_HOOK_FIXTURE_DIR="$fixtures_dir" "$CAPTURE_SCRIPT" PreToolUse 2>&1)"
  actual_code=$?
  set -e

  assert_exit_code 0 "$actual_code" "capture exits zero for valid payload"
  assert_eq "" "$output" "capture script writes no stdout or stderr"
  assert_file_exists "${fixtures_dir}/PreToolUse.jsonl" "valid payload fixture is created"

  actual_line="$(cat "${fixtures_dir}/PreToolUse.jsonl")"
  assert_eq '{"session_id":"capture-session-001","transcript_path":"/Users/example/.claude/projects/scratch/capture-session-001.jsonl","cwd":"/Users/example/src/scratch","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf '\''capture probe\\n'\''"}}' "$actual_line" "valid payload is compacted to one JSON line"
}

test_capture_logs_malformed_payload() {
  local fixtures_dir
  local output
  local actual_code
  fixtures_dir="${TMP_DIR}/malformed"

  set +e
  output="$(printf '{not json' | ALBION_HOOK_FIXTURE_DIR="$fixtures_dir" "$CAPTURE_SCRIPT" PreToolUse 2>&1)"
  actual_code=$?
  set -e

  assert_exit_code 0 "$actual_code" "capture exits zero for malformed payload"
  assert_eq "" "$output" "malformed capture writes no stdout or stderr"
  assert_file_exists "${fixtures_dir}/PreToolUse.malformed.log" "malformed payload log is created"
  assert_contains "$(cat "${fixtures_dir}/PreToolUse.malformed.log")" "{not json" "malformed payload is logged"
}

test_validator_passes_synthetic_fixtures() {
  local output
  local actual_code

  set +e
  output="$("$VALIDATOR_SCRIPT" "${ROOT_DIR}/tests/fixtures/hooks/synthetic" 2>&1)"
  actual_code=$?
  set -e

  assert_exit_code 0 "$actual_code" "validator accepts synthetic fixtures"
  assert_contains "$output" "PASS PreToolUse.jsonl: 2 line(s)" "validator reports PreToolUse synthetic fixture"
  assert_contains "$output" "PASS SessionStart.jsonl: 1 line(s)" "validator reports SessionStart synthetic fixture"
}

test_validator_fails_broken_fixture() {
  local broken_dir
  local output
  local actual_code
  broken_dir="${TMP_DIR}/broken"
  mkdir -p "$broken_dir"
  printf '%s\n' '{"session_id":"broken","transcript_path":"/tmp/transcript.jsonl","cwd":"/tmp","hook_event_name":"PreToolUse"}' > "${broken_dir}/PreToolUse.jsonl"

  set +e
  output="$("$VALIDATOR_SCRIPT" "$broken_dir" 2>&1)"
  actual_code=$?
  set -e

  assert_exit_code 1 "$actual_code" "validator rejects broken fixtures"
  assert_contains "$output" "FAIL PreToolUse.jsonl: 1 line(s)" "validator reports broken fixture"
  assert_contains "$output" "missing required keys: tool_name, tool_input" "validator reports missing event keys"
}

test_capture_compacts_valid_payload
test_capture_logs_malformed_payload
test_validator_passes_synthetic_fixtures
test_validator_fails_broken_fixture
