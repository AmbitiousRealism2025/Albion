#!/usr/bin/env bash
set -euo pipefail

main() {
  local script_dir
  local fixtures_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fixtures_dir="${1:-${script_dir}/../../fixtures/hooks}"

  python3 - "$fixtures_dir" <<'PY'
import json
import os
import sys

fixtures_dir = os.path.abspath(sys.argv[1])

required_keys = {
    "PreToolUse": [
        "session_id",
        "transcript_path",
        "cwd",
        "hook_event_name",
        "tool_name",
        "tool_input",
    ],
    "PostToolUse": [
        "session_id",
        "transcript_path",
        "cwd",
        "hook_event_name",
        "tool_name",
        "tool_input",
        "tool_response",
    ],
    "Stop": [
        "session_id",
        "transcript_path",
        "cwd",
        "hook_event_name",
        "stop_hook_active",
    ],
    "SessionStart": [
        "session_id",
        "transcript_path",
        "cwd",
        "hook_event_name",
        "source",
    ],
}


def iter_jsonl_files(root):
    for current_root, _, filenames in os.walk(root):
        for filename in sorted(filenames):
            if filename.endswith(".jsonl"):
                yield os.path.join(current_root, filename)


def relative(path):
    return os.path.relpath(path, fixtures_dir)


def validate_file(path):
    event_name = os.path.basename(path)[:-len(".jsonl")]
    expected_keys = required_keys.get(event_name)
    errors = []
    line_count = 0

    if expected_keys is None:
        errors.append(f"unknown event derived from filename: {event_name}")
        expected_keys = []

    with open(path, "r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            line_count += 1
            try:
                payload = json.loads(line)
            except json.JSONDecodeError as exc:
                errors.append(f"line {line_number}: invalid JSON: {exc.msg}")
                continue

            if not isinstance(payload, dict):
                errors.append(f"line {line_number}: payload must be a JSON object")
                continue

            missing_keys = [key for key in expected_keys if key not in payload]
            if missing_keys:
                errors.append(
                    f"line {line_number}: missing required keys: {', '.join(missing_keys)}"
                )

            hook_event_name = payload.get("hook_event_name")
            if hook_event_name is not None and hook_event_name != event_name:
                errors.append(
                    f"line {line_number}: hook_event_name is {hook_event_name!r}, expected {event_name!r}"
                )

    if line_count == 0:
        errors.append("file contains no fixture lines")

    return line_count, errors


if not os.path.isdir(fixtures_dir):
    print(f"FAIL {fixtures_dir}: fixture directory does not exist", file=sys.stderr)
    sys.exit(1)

jsonl_files = list(iter_jsonl_files(fixtures_dir))
if not jsonl_files:
    print(f"FAIL {fixtures_dir}: no .jsonl fixtures found", file=sys.stderr)
    sys.exit(1)

failure_count = 0
for path in jsonl_files:
    line_count, errors = validate_file(path)
    if errors:
        failure_count += 1
        print(f"FAIL {relative(path)}: {line_count} line(s)")
        for error in errors:
            print(f"  - {error}")
    else:
        print(f"PASS {relative(path)}: {line_count} line(s)")

if failure_count:
    sys.exit(1)
PY
}

main "$@"
