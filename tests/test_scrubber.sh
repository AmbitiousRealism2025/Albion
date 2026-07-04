#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-scrubber.$$"
SCRUBBER_SCRIPT="${ROOT_DIR}/plugin/scripts/workbench-scrubber.sh"
CAPTURED_POST_TOOL_USE="${ROOT_DIR}/tests/fixtures/hooks/captured/PostToolUse.jsonl"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

assert_not_contains() {
  local haystack
  local needle
  local message
  haystack="$1"
  needle="$2"
  message="${3:-string should not contain substring}"

  case "$haystack" in
    *"$needle"*)
      assert_fail "${message}: expected '${haystack}' not to contain '${needle}'"
      return 1
      ;;
  esac
}

file_mode() {
  local path
  path="$1"
  python3 - "$path" <<'PY'
import os
import stat
import sys

print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)))
PY
}

resolved_path() {
  local path
  path="$1"
  python3 - "$path" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve(strict=False))
PY
}

run_scrubber() {
  local name
  local payload
  local out_file
  local err_file
  name="$1"
  payload="$2"
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  printf '%s' "$payload" | ALBION_SCRUBBER_LOG="${TMP_DIR}/${name}.log" "$SCRUBBER_SCRIPT" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
}

json_payload() {
  local tool_name
  local file_path
  tool_name="$1"
  file_path="$2"
  python3 - "$tool_name" "$file_path" <<'PY'
import json
import sys

print(json.dumps({
    "hook_event_name": "PostToolUse",
    "tool_name": sys.argv[1],
    "tool_input": {
        "file_path": sys.argv[2],
        "content": "already written"
    },
    "tool_response": {
        "type": "create",
        "filePath": sys.argv[2]
    }
}))
PY
}

notice_context() {
  python3 - <<'PY' "$1"
import json
import sys

print(json.loads(sys.argv[1])["hookSpecificOutput"]["additionalContext"])
PY
}

write_secret_fixture() {
  local path
  path="$1"
  python3 - "$path" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text("""aws=AKIATESTTESTTESTTEST
github=ghp_TESTTOKENVALUEFAKE0000
api=sk-TEST_fake_key_value_000000000
slack=xoxb-TEST-TEST-TEST-TEST
private=-----BEGIN TEST PRIVATE KEY-----
TEST PRIVATE KEY BODY
-----END TEST PRIVATE KEY-----
auth=Bearer ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij1234567890
jwt=eyJTESTHEADER00.eyJTESTPAYLOAD0.eyJTESTSIGNATURE
token=Abcdef1234567890
""", encoding="utf-8")
PY
}

test_redacts_all_supported_secret_types_and_preserves_mode() {
  local workbench_dir
  local target
  local payload
  local before_mode
  local after_mode
  local content
  local context
  local resolved_target
  workbench_dir="${TMP_DIR}/project/.agent-workbench/task"
  target="${workbench_dir}/notes.md"
  mkdir -p "$workbench_dir"
  write_secret_fixture "$target"
  chmod 640 "$target"
  before_mode="$(file_mode "$target")"
  resolved_target="$(resolved_path "$target")"

  payload="$(json_payload Write "$target")"
  run_scrubber "redacts-all" "$payload"

  assert_exit_code 0 "$RUN_CODE" "scrubber exits zero after redacting secrets"
  assert_eq "" "$RUN_STDERR" "scrubber writes no stderr"
  after_mode="$(file_mode "$target")"
  assert_eq "$before_mode" "$after_mode" "scrubber preserves file mode"

  content="$(cat "$target")"
  assert_contains "$content" "[REDACTED:aws_access_key]" "AWS access key is redacted"
  assert_contains "$content" "[REDACTED:github_token]" "GitHub token is redacted"
  assert_contains "$content" "[REDACTED:api_key]" "API key is redacted"
  assert_contains "$content" "[REDACTED:slack_token]" "Slack token is redacted"
  assert_contains "$content" "[REDACTED:private_key]" "private key block is redacted"
  assert_contains "$content" "[REDACTED:bearer_token]" "Bearer token is redacted"
  assert_contains "$content" "[REDACTED:jwt]" "JWT is redacted"
  assert_contains "$content" "token=[REDACTED:generic_secret]" "generic secret assignment is redacted"
  assert_not_contains "$content" "AKIATESTTESTTESTTEST" "AWS fake value is removed"
  assert_not_contains "$content" "ghp_TESTTOKENVALUEFAKE0000" "GitHub fake value is removed"
  assert_not_contains "$content" "sk-TEST_fake_key_value_000000000" "API fake value is removed"
  assert_not_contains "$content" "xoxb-TEST-TEST-TEST-TEST" "Slack fake value is removed"
  assert_not_contains "$content" "TEST PRIVATE KEY BODY" "private key body is removed"
  assert_not_contains "$content" "Bearer ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij1234567890" "Bearer fake value is removed"
  assert_not_contains "$content" "eyJTESTHEADER00.eyJTESTPAYLOAD0.eyJTESTSIGNATURE" "JWT fake value is removed"
  assert_not_contains "$content" "Abcdef1234567890" "generic fake value is removed"

  context="$(notice_context "$RUN_STDOUT")"
  assert_contains "$context" "Redacted 8 secret-like value(s)" "notice reports redaction count"
  assert_contains "$context" "$resolved_target" "notice reports scrubbed path"
  assert_contains "$context" "types: private_key, aws_access_key, github_token, api_key, slack_token, bearer_token, jwt, generic_secret" "notice reports redaction types"
  assert_contains "$context" "Workbench files must not contain credentials." "notice includes workbench warning"
}

test_clean_workbench_file_is_untouched_and_silent() {
  local workbench_dir
  local target
  local before
  workbench_dir="${TMP_DIR}/project/.agent-workbench/task"
  target="${workbench_dir}/clean.md"
  mkdir -p "$workbench_dir"
  printf 'ordinary workbench note\n[REDACTED:api_key]\n' >"$target"
  before="$(cat "$target")"

  run_scrubber "clean" "$(json_payload Edit "$target")"

  assert_exit_code 0 "$RUN_CODE" "clean workbench exits zero"
  assert_eq "" "$RUN_STDOUT" "clean workbench emits no stdout"
  assert_eq "" "$RUN_STDERR" "clean workbench emits no stderr"
  assert_eq "$before" "$(cat "$target")" "clean workbench file is unchanged"
}

test_non_workbench_file_is_untouched_and_silent() {
  local target
  local before
  target="${TMP_DIR}/project/plain-notes.md"
  mkdir -p "$(dirname "$target")"
  printf 'token=Abcdef1234567890\n' >"$target"
  before="$(cat "$target")"

  run_scrubber "non-workbench" "$(json_payload Write "$target")"

  assert_exit_code 0 "$RUN_CODE" "non-workbench path exits zero"
  assert_eq "" "$RUN_STDOUT" "non-workbench path emits no stdout"
  assert_eq "" "$RUN_STDERR" "non-workbench path emits no stderr"
  assert_eq "$before" "$(cat "$target")" "non-workbench file is unchanged"
}

test_double_run_is_idempotent() {
  local workbench_dir
  local target
  local payload
  local first_content
  workbench_dir="${TMP_DIR}/project/.agent-workbench/task"
  target="${workbench_dir}/idempotent.md"
  mkdir -p "$workbench_dir"
  printf 'password=Abcdef1234567890\n' >"$target"
  payload="$(json_payload NotebookEdit "$target")"

  run_scrubber "idempotent-first" "$payload"
  assert_exit_code 0 "$RUN_CODE" "first scrub exits zero"
  assert_contains "$RUN_STDOUT" "Redacted 1 secret-like value(s)" "first scrub reports one redaction"
  first_content="$(cat "$target")"

  run_scrubber "idempotent-second" "$payload"
  assert_exit_code 0 "$RUN_CODE" "second scrub exits zero"
  assert_eq "" "$RUN_STDOUT" "second scrub emits no stdout"
  assert_eq "" "$RUN_STDERR" "second scrub emits no stderr"
  assert_eq "$first_content" "$(cat "$target")" "second scrub does not change redacted file"
}

test_malformed_stdin_exits_zero_and_logs_without_output() {
  run_scrubber "malformed" "{not json"

  assert_exit_code 0 "$RUN_CODE" "malformed stdin exits zero"
  assert_eq "" "$RUN_STDOUT" "malformed stdin emits no stdout"
  assert_eq "" "$RUN_STDERR" "malformed stdin emits no stderr"
  assert_file_exists "${TMP_DIR}/malformed.log" "malformed stdin is logged"
  assert_contains "$(cat "${TMP_DIR}/malformed.log")" "malformed stdin: invalid JSON" "malformed log names parse failure"
}

test_captured_non_workbench_post_tool_use_payloads_are_silent() {
  local line_number
  local payload
  line_number=0
  while IFS= read -r payload; do
    line_number=$((line_number + 1))
    run_scrubber "captured-${line_number}" "$payload"
    assert_exit_code 0 "$RUN_CODE" "captured payload ${line_number} exits zero"
    assert_eq "" "$RUN_STDOUT" "captured payload ${line_number} emits no stdout"
    assert_eq "" "$RUN_STDERR" "captured payload ${line_number} emits no stderr"
  done <"$CAPTURED_POST_TOOL_USE"
}

test_redacts_all_supported_secret_types_and_preserves_mode
test_clean_workbench_file_is_untouched_and_silent
test_non_workbench_file_is_untouched_and_silent
test_double_run_is_idempotent
test_malformed_stdin_exits_zero_and_logs_without_output
test_captured_non_workbench_post_tool_use_payloads_are_silent
