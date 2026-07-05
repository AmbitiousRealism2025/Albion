#!/usr/bin/env bash
set -euo pipefail

# These tests exercise the hooks' ACTIVE behavior (as if launched by bin/albion).
export ALBION_ACTIVE=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_DIR="${TMP_ROOT%/}/albion-test-inject.$$"
HOOK="${ROOT_DIR}/plugin/scripts/session-start-inject.sh"
CAPTURED_SESSION_START="${ROOT_DIR}/tests/fixtures/hooks/captured/SessionStart.jsonl"

# shellcheck disable=SC1091
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

run_inject() {
  local name
  local payload
  local workbench_root
  local state_dir
  local out_file
  local err_file

  name="$1"
  payload="$2"
  workbench_root="$3"
  state_dir="$4"
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  ALBION_WORKBENCH_ROOT="$workbench_root" \
    ALBION_STATE_DIR="$state_dir" \
    ALBION_INJECT_LOG="${TMP_DIR}/${name}.log" \
    "$HOOK" >"$out_file" 2>"$err_file" <<<"$payload"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
}

json_field() {
  local payload
  local field_path
  payload="$1"
  field_path="$2"
  python3 - "$payload" "$field_path" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
value = data
for part in sys.argv[2].split("."):
    value = value[part]
print(value)
PY
}

payload_with_source() {
  local source_name
  source_name="$1"
  python3 - "$CAPTURED_SESSION_START" "$source_name" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fixture:
    payload = json.loads(fixture.readline())
payload["source"] = sys.argv[2]
print(json.dumps(payload, separators=(",", ":")))
PY
}

payload_session_id() {
  python3 - "$1" <<'PY'
import json
import sys

print(json.loads(sys.argv[1])["session_id"])
PY
}

write_state() {
  local state_dir
  local session_id
  state_dir="$1"
  session_id="$2"
  mkdir -p "$state_dir"
  python3 - "$state_dir/${session_id}.json" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(
    json.dumps(
        {
            "strikes": {"Bash": 2, "Edit": 3, "Read": 1},
            "last_test": {"command": "bash tests/run.sh", "status": "fail"},
            "tasks": {"open": 2},
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
PY
}

make_task() {
  local workbench_root
  local name
  local task_content
  local state_map_content
  workbench_root="$1"
  name="$2"
  task_content="$3"
  state_map_content="$4"

  mkdir -p "$workbench_root/fable-mode/$name"
  printf '%s\n' "$task_content" >"$workbench_root/fable-mode/$name/task.md"
  printf '%s\n' "$state_map_content" >"$workbench_root/fable-mode/$name/state-map.md"
}

assert_valid_hook_json() {
  local payload
  payload="$1"
  python3 - "$payload" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
hook_output = data["hookSpecificOutput"]
assert hook_output["hookEventName"] == "SessionStart"
assert isinstance(hook_output["additionalContext"], str)
PY
}

test_rich_workbench_state_and_sources() {
  local workbench_root
  local state_dir
  local source_name
  local payload
  local session_id
  local context

  for source_name in startup resume clear compact; do
    workbench_root="${TMP_DIR}/rich-${source_name}/workbench"
    state_dir="${TMP_DIR}/rich-${source_name}/state"
    payload="$(payload_with_source "$source_name")"
    session_id="$(payload_session_id "$payload")"
    make_task "$workbench_root" "active-task" "Primary task body for ${source_name}." "State map body for ${source_name}."
    write_state "$state_dir" "$session_id"

    run_inject "rich-${source_name}" "$payload" "$workbench_root" "$state_dir"
    assert_exit_code 0 "$RUN_CODE" "inject exits zero for source ${source_name}"
    assert_eq "" "$RUN_STDERR" "inject writes no stderr for source ${source_name}"
    assert_valid_hook_json "$RUN_STDOUT"
    context="$(json_field "$RUN_STDOUT" "hookSpecificOutput.additionalContext")"
    assert_contains "$context" "Albion state re-injected (source: ${source_name})." "context echoes source ${source_name}"
    assert_contains "$context" "Primary task body for ${source_name}." "context includes task.md for ${source_name}"
    assert_contains "$context" "State map body for ${source_name}." "context includes state-map.md for ${source_name}"
    assert_contains "$context" "Open strike: strikes.Bash=2." "context includes strike line"
    assert_contains "$context" "Open strike: strikes.Edit=3." "context includes second strike line"
    assert_contains "$context" 'Last test: {"command":"bash tests/run.sh","status":"fail"}.' "context includes last_test line"
    assert_contains "$context" "Open tasks: tasks.open=2." "context includes open tasks line"
  done
}

test_captured_payload_shapes_parse() {
  local workbench_root
  local state_dir
  local payload
  local index
  local context

  workbench_root="${TMP_DIR}/captured/workbench"
  state_dir="${TMP_DIR}/captured/state"
  make_task "$workbench_root" "captured-task" "Captured payload task." "Captured payload state."
  index=0
  while IFS= read -r payload; do
    run_inject "captured-${index}" "$payload" "$workbench_root" "$state_dir"
    assert_exit_code 0 "$RUN_CODE" "captured payload ${index} exits zero"
    assert_valid_hook_json "$RUN_STDOUT"
    context="$(json_field "$RUN_STDOUT" "hookSpecificOutput.additionalContext")"
    assert_contains "$context" "Albion state re-injected (source: startup)." "captured payload ${index} source is echoed"
    index=$((index + 1))
  done <"$CAPTURED_SESSION_START"
  assert_eq "4" "$index" "all captured SessionStart payloads were exercised"
}

test_oversized_task_truncates_under_budget_and_skips_secret_lines() {
  local workbench_root
  local state_dir
  local payload
  local task_file
  local context
  local context_len

  workbench_root="${TMP_DIR}/oversize/workbench"
  state_dir="${TMP_DIR}/oversize/state"
  payload="$(payload_with_source "compact")"
  make_task "$workbench_root" "large-task" "placeholder" "state map should lose priority when task is huge"
  task_file="$workbench_root/fable-mode/large-task/task.md"
  python3 - "$task_file" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(
    "large task begins\n"
    + "AKIATESTTESTTESTTEST should not be injected\n"
    + "sk-" + ("A" * 24) + " should not be injected\n"
    + "Bearer " + ("B" * 45) + " should not be injected\n"
    + "-----BEGIN PRIVATE KEY-----\nprivate\n-----END PRIVATE KEY-----\n"
    + ("x" * 12500),
    encoding="utf-8",
)
PY

  run_inject "oversize" "$payload" "$workbench_root" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "oversized task exits zero"
  assert_valid_hook_json "$RUN_STDOUT"
  context="$(json_field "$RUN_STDOUT" "hookSpecificOutput.additionalContext")"
  context_len="$(python3 - "$context" <<'PY'
import sys
print(len(sys.argv[1]))
PY
)"
  if [ "$context_len" -ge 9000 ]; then
    assert_fail "context should stay under 9000 characters, got ${context_len}"
  fi
  assert_contains "$context" "large task begins" "oversized context keeps task prefix"
  assert_contains "$context" "…[truncated; full content: $task_file]" "oversized context has truncation marker"
  case "$context" in
    *AKIATESTTESTTESTTEST*|*sk-AAAAAAAAAAAAAAAAAAAAAAAA*|*"Bearer BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"*|*"BEGIN PRIVATE KEY"*)
      assert_fail "context should omit secret-shaped lines"
      ;;
  esac
}

test_newest_task_wins_and_other_is_named() {
  local workbench_root
  local state_dir
  local payload
  local context

  workbench_root="${TMP_DIR}/newest/workbench"
  state_dir="${TMP_DIR}/newest/state"
  payload="$(payload_with_source "resume")"
  make_task "$workbench_root" "older-task" "Older task content." "Older state map."
  sleep 1
  make_task "$workbench_root" "newer-task" "Newer task content." "Newer state map."

  run_inject "newest" "$payload" "$workbench_root" "$state_dir"
  assert_exit_code 0 "$RUN_CODE" "newest task exits zero"
  assert_valid_hook_json "$RUN_STDOUT"
  context="$(json_field "$RUN_STDOUT" "hookSpecificOutput.additionalContext")"
  assert_contains "$context" "Latest workbench task: newer-task" "newest task is selected"
  assert_contains "$context" "Newer task content." "newest task content is included"
  assert_contains "$context" "Other workbench tasks present: older-task." "older task is named as other"
  case "$context" in
    *"Older task content."*)
      assert_fail "older task content should not be injected"
      ;;
  esac
}

test_empty_state_and_no_workbench_is_silent() {
  local payload

  payload="$(payload_with_source "startup")"
  run_inject "empty" "$payload" "${TMP_DIR}/empty/workbench" "${TMP_DIR}/empty/state"
  assert_exit_code 0 "$RUN_CODE" "empty session exits zero"
  assert_eq "" "$RUN_STDOUT" "empty session produces no stdout"
  assert_eq "" "$RUN_STDERR" "empty session produces no stderr"
}

test_malformed_stdin_exits_zero_silently() {
  run_inject "malformed" "{not json" "${TMP_DIR}/malformed/workbench" "${TMP_DIR}/malformed/state"
  assert_exit_code 0 "$RUN_CODE" "malformed input exits zero"
  assert_eq "" "$RUN_STDOUT" "malformed input produces no stdout"
  assert_eq "" "$RUN_STDERR" "malformed input produces no stderr"
}

test_rich_workbench_state_and_sources
test_captured_payload_shapes_parse
test_oversized_task_truncates_under_budget_and_skips_secret_lines
test_newest_task_wins_and_other_is_named
test_empty_state_and_no_workbench_is_silent
test_malformed_stdin_exits_zero_silently
