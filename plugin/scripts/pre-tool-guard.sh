#!/usr/bin/env bash
set -euo pipefail

DENY_REASON=""

log_guard() {
  local message
  message="$1"

  printf '%s\n' "$message" >>"${ALBION_GUARD_LOG:-/dev/null}" 2>/dev/null || true
}

fail_open() {
  log_guard "$1"
  exit 0
}

on_error() {
  fail_open "pre-tool guard internal error; allowing command"
}

trap on_error ERR

parse_payload() {
  local payload
  payload="$1"

  ALBION_HOOK_PAYLOAD="$payload" python3 -c '
import json
import os
import sys

try:
    payload = json.loads(os.environ["ALBION_HOOK_PAYLOAD"])
except Exception as exc:
    print(f"malformed hook input: {exc}")
    sys.exit(64)

if payload.get("tool_name") != "Bash":
    print("PASS")
    sys.exit(0)

command = payload.get("tool_input", {}).get("command")
if not isinstance(command, str):
    print("PASS")
    sys.exit(0)

print("BASH")
print(command, end="")
'
}

emit_deny() {
  local reason
  reason="$1"

  python3 - "$reason" <<'PY'
import json
import sys

reason = sys.argv[1]
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }
}, separators=(",", ":")))
PY
}

decode_escapes() {
  local input
  input="$1"

  printf '%b' "$input"
}

normalize_command() {
  local cmd
  cmd="$1"

  cmd=$(printf '%s' "$cmd" | sed "s/\\\$'\\([^']*\\)'/\\1/g")
  cmd=$(printf '%s' "$cmd" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')
  cmd=$(decode_escapes "$cmd")
  cmd=$(printf '%s' "$cmd" | tr '\r\n\t' '   ')
  cmd=$(printf '%s' "$cmd" | tr -d '\000-\010\013\014\016-\037\177')
  cmd=$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')
  cmd=$(printf '%s' "$cmd" | sed 's/\\[[:space:]]*$//g; s/\\[[:space:]]\+/ /g')
  cmd=$(printf '%s' "$cmd" | sed 's/\\//g')
  cmd=$(printf '%s' "$cmd" | sed 's/\\x\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')
  cmd=$(decode_escapes "$cmd")
  cmd=$(printf '%s' "$cmd" | sed 's/\\\([0-7][0-7][0-7]\)/\\0\1/g')
  cmd=$(decode_escapes "$cmd")
  cmd=$(printf '%s' "$cmd" | sed "s/'\([^']*\)'/\1/g")
  cmd=$(printf '%s' "$cmd" | sed 's/"\([^"]*\)"/\1/g')
  cmd=$(printf '%s' "$cmd" | sed "s/\\\$'\\\\x\([0-9A-Fa-f][0-9A-Fa-f]\)'/\\\\x\1/g")
  cmd=$(decode_escapes "$cmd")
  cmd=$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')

  printf '%s' "$cmd"
}

sanitize_command() {
  local cmd
  cmd="$1"

  cmd=$(printf '%s' "$cmd" | tr -d '`$;&|<>')
  cmd=$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')
  printf '%s' "$cmd"
}

lowercase() {
  local input
  input="$1"

  printf '%s' "$input" | tr '[:upper:]' '[:lower:]'
}

contains_fork_bomb() {
  local compact
  compact=$(printf '%s' "$1" | tr -d '[:space:]')

  [[ "$compact" == *':(){:|:&};:'* ]]
}

match_rm_root() {
  local cmd
  local command_start
  local wrapper
  local rm_cmd
  local rm_flags
  local root_target
  local regex
  cmd="$1"
  command_start='(^|[;&|()])[[:space:]]*'
  wrapper='((command|builtin)[[:space:]]+)*'
  rm_cmd="${wrapper}((/usr)?/s?bin/)?rm"
  rm_flags='(-[^[:space:];&|]*r[^[:space:];&|]*f[^[:space:];&|]*|-[^[:space:];&|]*f[^[:space:];&|]*r[^[:space:];&|]*|-r[[:space:]]+-f|-f[[:space:]]+-r|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)'
  root_target='(/|//+|/[*]+|/[.]/?|/[.][.]/?|~|[$]home)'
  regex="${command_start}${rm_cmd}[[:space:]]+${rm_flags}([[:space:]]+--)?([[:space:]]+[^[:space:];&|]+)*[[:space:]]+${root_target}([[:space:];&|]|$)"

  [[ "$cmd" =~ $regex ]]
}

match_sudo_rm() {
  local cmd
  local regex
  cmd="$1"
  regex='(^|[;&|()])[[:space:]]*((command|builtin)[[:space:]]+)*sudo[[:space:]]+((command|builtin)[[:space:]]+|((/usr)?/s?bin/))*rm([[:space:]]|$)'

  [[ "$cmd" =~ $regex ]]
}

match_mkfs() {
  local cmd
  local regex
  cmd="$1"
  regex='(^|[;&|()])[[:space:]]*((command|builtin|sudo)[[:space:]]+|((/usr)?/s?bin/))*mkfs([.[:space:];&|]|$)'

  [[ "$cmd" =~ $regex ]]
}

match_dd_device_write() {
  local cmd
  local regex
  cmd="$1"
  regex='(^|[;&|()])[[:space:]]*((command|builtin|sudo)[[:space:]]+|((/usr)?/s?bin/))*dd([[:space:]][^;&|]*)?[[:space:]]+of=/dev/'

  [[ "$cmd" =~ $regex ]]
}

match_pipe_to_shell() {
  local cmd
  local regex
  cmd="$1"
  regex='(^|[;&|()])[[:space:]]*((command|builtin)[[:space:]]+|((/usr)?/bin/))*(curl|wget)[^|]*[|][[:space:]]*((command|builtin)[[:space:]]+|((/usr)?/bin/))*(bash|sh)([[:space:];&|]|$)'

  [[ "$cmd" =~ $regex ]]
}

match_git_force_protected() {
  local cmd
  cmd="$1"

  [[ "$cmd" =~ (^|[\;\&\|\(\)])[[:space:]]*((command|builtin)[[:space:]]+)*git[[:space:]]+push([[:space:]][^\;\&\|]*)? ]] || return 1
  [[ "$cmd" =~ (^|[[:space:]])(--force|-f)([[:space:]]|$) ]] || return 1
  [[ "$cmd" =~ (^|[[:space:]/:])((refs/heads/)?(main|master))([[:space:];&|:]|$) ]]
}

match_chmod_root() {
  local cmd
  local regex
  local root_target
  cmd="$1"
  root_target='(/|//+|/[*]+|/[.]/?|/[.][.]/?)'
  regex="(^|[;&|()])[[:space:]]*((command|builtin|sudo)[[:space:]]+|((/usr)?/bin/))*chmod[[:space:]]+-r[[:space:]]+777([[:space:]]+--)?[[:space:]]+${root_target}([[:space:];&|]|$)"

  [[ "$cmd" =~ $regex ]]
}

match_eval_command_substitution() {
  local cmd
  local regex
  cmd="$1"
  regex='(^|[;&|()])[[:space:]]*((command|builtin)[[:space:]]+)*eval[[:space:]]+[$][(]'

  [[ "$cmd" =~ $regex ]]
}

find_denial() {
  local normalized_lower
  local sanitized_lower
  normalized_lower="$1"
  sanitized_lower="$2"

  if match_rm_root "$normalized_lower" || match_rm_root "$sanitized_lower"; then
    DENY_REASON="blocked: \`rm -rf\` targeting filesystem root; narrow the path explicitly"
    return 0
  fi

  if match_sudo_rm "$normalized_lower"; then
    DENY_REASON="blocked: \`sudo rm\` can remove protected paths; use a non-sudo removal scoped to the workspace"
    return 0
  fi

  if contains_fork_bomb "$normalized_lower"; then
    DENY_REASON='blocked: fork bomb pattern would exhaust local process resources; do not run self-replicating shell functions'
    return 0
  fi

  if match_mkfs "$normalized_lower"; then
    DENY_REASON="blocked: \`mkfs\` formats block devices; use a non-destructive inspection command instead"
    return 0
  fi

  if match_dd_device_write "$normalized_lower"; then
    DENY_REASON="blocked: \`dd\` writing to \`/dev/\` can overwrite devices; write to an explicit regular file instead"
    return 0
  fi

  if match_pipe_to_shell "$normalized_lower"; then
    DENY_REASON='blocked: network download piped directly to a shell; download, inspect, and run a pinned script explicitly'
    return 0
  fi

  if match_git_force_protected "$normalized_lower"; then
    DENY_REASON="blocked: force-push to \`main\` or \`master\`; use a review branch or a non-force push"
    return 0
  fi

  if match_chmod_root "$normalized_lower"; then
    DENY_REASON="blocked: \`chmod -R 777\` targeting filesystem root; scope permissions to a specific project path"
    return 0
  fi

  if match_eval_command_substitution "$normalized_lower"; then
    DENY_REASON="blocked: \`eval\` of command substitution can execute generated shell code; inspect the generated command first"
    return 0
  fi

  return 1
}

main() {
  local parser_output
  local payload
  local command
  local normalized
  local normalized_lower
  local sanitized_lower

  payload="$(cat)"

  if ! parser_output="$(parse_payload "$payload")"; then
    fail_open "${parser_output:-malformed hook input}"
  fi

  if [ "$parser_output" = "PASS" ]; then
    exit 0
  fi

  case "$parser_output" in
    BASH$'\n'*)
      command="${parser_output#BASH$'\n'}"
      ;;
    *)
      fail_open "unexpected pre-tool guard parser output; allowing command"
      ;;
  esac

  normalized="$(normalize_command "$command")"
  normalized_lower="$(lowercase "$normalized")"
  sanitized_lower="$(lowercase "$(sanitize_command "$normalized")")"

  if find_denial "$normalized_lower" "$sanitized_lower"; then
    emit_deny "$DENY_REASON"
  fi
}

main "$@"
