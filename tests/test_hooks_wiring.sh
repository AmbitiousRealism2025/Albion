#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-hooks-wiring.$$"
PATH_FARM_TOOLS=(
  bash
  sh
  python3
  cat
  dirname
  readlink
  mktemp
  grep
  sed
  basename
  rm
  tr
  mkdir
)

cd "$ROOT_DIR"
. tests/lib/assert.sh

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

make_doctor_path() {
  local stub_dir
  local tool
  local tool_path
  stub_dir="${TMP_DIR}/doctor-bin"
  mkdir -p "$stub_dir"

  for tool in "${PATH_FARM_TOOLS[@]}"; do
    if ! tool_path="$(command -v "$tool")"; then
      printf 'required test tool not found on host PATH: %s\n' "$tool" >&2
      exit 1
    fi
    ln -s "$tool_path" "${stub_dir}/${tool}"
  done

  cat >"${stub_dir}/claude" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  printf 'Claude Code %s\n' "${CLAUDE_STUB_VERSION:?}"
  exit 0
fi

printf 'stub claude invoked\n'
STUB
  chmod +x "${stub_dir}/claude"

  cat >"${stub_dir}/tmux" <<'STUB'
#!/usr/bin/env bash
printf 'tmux stub\n'
STUB
  chmod +x "${stub_dir}/tmux"

  printf '%s\n' "$stub_dir"
}

validate_hooks_json() {
  python3 - "$ROOT_DIR" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
plugin_root = root / "plugin"
hooks_path = plugin_root / "hooks" / "hooks.json"
supported_events = {"PreToolUse", "PostToolUse", "Stop", "SessionStart"}
expected = [
    ("PreToolUse", "Bash", "pre-tool-guard.sh"),
    ("PreToolUse", "Read", "image-read-intercept.sh"),
    ("PostToolUse", "*", "post-tool-strikes.sh"),
    ("PostToolUse", "Write|Edit|NotebookEdit", "workbench-scrubber.sh"),
    ("Stop", None, "stop-gate.sh"),
    ("SessionStart", "startup|resume|clear|compact", "session-start-inject.sh"),
]

with hooks_path.open("r", encoding="utf-8") as handle:
    config = json.load(handle)

actual = []
for event_name, entries in config.get("hooks", {}).items():
    assert event_name in supported_events, f"unsupported event: {event_name}"
    assert isinstance(entries, list), f"{event_name} entries must be a list"
    for entry in entries:
        matcher = entry.get("matcher")
        hooks = entry.get("hooks")
        assert isinstance(hooks, list) and hooks, f"{event_name} entry has no hooks"
        for hook in hooks:
            assert hook.get("type") == "command", f"{event_name} hook type must be command"
            command = hook.get("command")
            assert isinstance(command, list) and command, f"{event_name} command must be exec-form list"
            script = command[0].replace("${CLAUDE_PLUGIN_ROOT}", str(plugin_root))
            script_path = pathlib.Path(script)
            assert script_path.is_file(), f"referenced script missing: {script_path}"
            assert script_path.stat().st_mode & 0o111, f"referenced script not executable: {script_path}"
            actual.append((event_name, matcher, script_path.name))

assert actual == expected, f"hook wiring mismatch: {actual!r}"
for event_name, matcher, script_name in actual:
    if script_name != "stop-gate.sh":
        assert isinstance(matcher, str) and matcher, f"{event_name} {script_name} requires a non-empty matcher"
PY
}

run_verify_hooks() {
  local output
  output="$("${ROOT_DIR}/plugin/scripts/verify-hooks.sh")"
  assert_contains "$output" "PASS hook verification" "verification runner should pass"
}

run_doctor_hook_suite() {
  local run_path
  local output
  local exit_code
  local err_file
  run_path="$(make_doctor_path)"
  err_file="${TMP_DIR}/doctor.err"

  set +e
  output="$(env -i TMPDIR="${TMPDIR:-/tmp}" PATH="$run_path" ALBION_ZAI_TOKEN=test-token CLAUDE_STUB_VERSION=2.1.200 "${ROOT_DIR}/bin/albion-doctor" --offline 2>"$err_file")"
  exit_code=$?
  set -e

  assert_exit_code 0 "$exit_code" "offline doctor should pass with hook suite enabled"
  assert_contains "$output" "PASS hook-suite: PASS hook verification" "doctor should report hook-suite PASS"
  assert_not_contains "$output" "SKIP hook-suite" "hook-suite should not be skipped"
  assert_eq "" "$(cat "$err_file")" "offline doctor should not write stderr"
}

validate_hooks_json
run_verify_hooks
run_doctor_hook_suite
