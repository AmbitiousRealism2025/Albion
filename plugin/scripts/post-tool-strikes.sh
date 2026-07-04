#!/usr/bin/env bash
set -euo pipefail

log_line() {
  local message
  message="$1"
  (printf '%s\n' "$message" >>"${ALBION_STRIKES_LOG:-/dev/null}") 2>/dev/null || true
}

resolved_script_dir() {
  local source_path
  local dir_path
  local link_target
  source_path="${BASH_SOURCE[0]}"

  while [ -L "$source_path" ]; do
    dir_path="$(cd -P "$(dirname "$source_path")" && pwd)"
    link_target="$(readlink "$source_path")"
    case "$link_target" in
      /*) source_path="$link_target" ;;
      *) source_path="${dir_path}/${link_target}" ;;
    esac
  done

  cd -P "$(dirname "$source_path")" && pwd
}

parse_payload() {
  python3 -c '
import json
import re
import shlex
import sys


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def explicit_failure(response):
    for obj in walk(response):
        if obj.get("is_error") is True:
            return True
        if obj.get("success") is False:
            return True
    return False


def bash_failure(response):
    if not isinstance(response, dict):
        return False
    stderr = response.get("stderr")
    if not isinstance(stderr, str) or stderr == "":
        return False
    exit_code = response.get("exit_code")
    interrupted = response.get("interrupted")
    if isinstance(exit_code, int) and not isinstance(exit_code, bool) and exit_code != 0:
        return True
    return interrupted is True


def first_command_token(command):
    if not isinstance(command, str):
        return ""
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()
    return parts[0] if parts else ""


def normalize(operation):
    normalized = operation.replace(":", "__")
    normalized = re.sub(r"[^A-Za-z0-9_]+", "_", normalized)
    normalized = normalized.strip("_")
    return normalized or "unknown"


try:
    payload = json.load(sys.stdin)
except Exception as error:
    print(f"PARSE_ERROR\tinvalid json: {error}")
    raise SystemExit(0)

if not isinstance(payload, dict):
    print("PARSE_ERROR\tpayload is not an object")
    raise SystemExit(0)

session_id = payload.get("session_id")
tool_name = payload.get("tool_name")
tool_input = payload.get("tool_input")
tool_response = payload.get("tool_response")

if not isinstance(session_id, str) or session_id == "":
    print("PARSE_ERROR\tmissing session_id")
    raise SystemExit(0)
if not isinstance(tool_name, str) or tool_name == "":
    print("PARSE_ERROR\tmissing tool_name")
    raise SystemExit(0)
if not isinstance(tool_input, dict):
    print("PARSE_ERROR\tmissing tool_input")
    raise SystemExit(0)

target = ""
file_path = tool_input.get("file_path")
if isinstance(file_path, str) and file_path != "":
    target = file_path
elif tool_name == "Bash":
    target = first_command_token(tool_input.get("command"))

operation = f"{tool_name}:{target}" if target else tool_name
failed = explicit_failure(tool_response) or (tool_name == "Bash" and bash_failure(tool_response))

print(session_id)
print(f"strikes.{normalize(operation)}")
print(operation)
print("fail" if failed else "success")
'
}

json_context() {
  local context
  context="$1"
  python3 -c '
import json
import sys

context = sys.argv[1]
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": context,
    },
}, separators=(",", ":")))
' "$context"
}

truncated_operation() {
  local operation
  operation="$1"
  if [ "${#operation}" -gt 240 ]; then
    printf '%s...\n' "${operation:0:240}"
  else
    printf '%s\n' "$operation"
  fi
}

emit_context() {
  local count
  local operation
  local display_operation
  local context
  count="$1"
  operation="$2"
  display_operation="$(truncated_operation "$operation")"

  context="Strike ${count} of 3 on ${display_operation}: the same change has now failed twice."
  if [ "$count" -ge 3 ]; then
    context="${context} Before retrying, record the contradiction (counterexamples log) and shrink the next step to the smallest falsifiable check; revert is the escalation after repeated counterexample loops."
  fi

  json_context "$context"
}

run_hook() {
  local script_dir
  local root_dir
  local state_lib
  local parsed
  local session_id
  local state_key
  local operation
  local status
  local count
  local existing_count

  script_dir="$(resolved_script_dir)"
  root_dir="$(cd "${script_dir}/../.." && pwd)"
  state_lib="${root_dir}/state/state-lib.sh"
  if [ ! -f "$state_lib" ]; then
    log_line "post-tool-strikes: missing state-lib.sh at ${state_lib}"
    return 0
  fi

  # shellcheck source=state/state-lib.sh
  . "$state_lib"

  if ! parsed="$(parse_payload)"; then
    log_line "post-tool-strikes: payload parser failed"
    return 0
  fi

  case "$parsed" in
    PARSE_ERROR$'\t'*)
      log_line "post-tool-strikes: ${parsed#*$'\t'}"
      return 0
      ;;
  esac

  session_id="$(printf '%s\n' "$parsed" | sed -n '1p')"
  state_key="$(printf '%s\n' "$parsed" | sed -n '2p')"
  operation="$(printf '%s\n' "$parsed" | sed -n '3p')"
  status="$(printf '%s\n' "$parsed" | sed -n '4p')"

  if [ "$status" = "success" ]; then
    if ! existing_count="$(albion_state_get "$session_id" "$state_key" __albion_missing__ 2>/dev/null)"; then
      log_line "post-tool-strikes: failed to read ${state_key} for ${session_id}"
      return 0
    fi
    if [ "$existing_count" = "__albion_missing__" ]; then
      return 0
    fi
    if ! albion_state_del "$session_id" "$state_key" >/dev/null 2>&1; then
      log_line "post-tool-strikes: failed to delete ${state_key} for ${session_id}"
    fi
    return 0
  fi

  if [ "$status" != "fail" ]; then
    log_line "post-tool-strikes: unknown parsed status ${status}"
    return 0
  fi

  if ! count="$(albion_state_incr "$session_id" "$state_key" 2>/dev/null)"; then
    log_line "post-tool-strikes: failed to increment ${state_key} for ${session_id}"
    return 0
  fi

  if [ "$count" -ge 2 ]; then
    emit_context "$count" "$operation"
  fi
}

run_hook "$@" || log_line "post-tool-strikes: unexpected hook failure"
exit 0
