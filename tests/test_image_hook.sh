#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-image-hook.$$"
HOOK="${ROOT_DIR}/plugin/scripts/image-read-intercept.sh"
RUN_STDOUT=""
RUN_CODE=0

cd "$ROOT_DIR"
source tests/lib/assert.sh

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

make_vision_stub() {
  local stub_path
  stub_path="${TMP_DIR}/albion-vision-stub"

  cat >"$stub_path" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "${ALBION_STUB_VISION_MODE:-success}" in
  fail)
    exit 42
    ;;
  oversized)
    python3 - <<'PY'
print("A" * 4500, end="")
PY
    ;;
  token)
    printf 'description includes token %s\n' "${ALBION_ZAI_TOKEN:-missing-token}"
    ;;
  *)
    printf 'stub description for %s\n' "$1"
    ;;
esac
STUB
  chmod +x "$stub_path"
  printf '%s' "$stub_path"
}

payload_for_read() {
  local file_path
  file_path="$1"

  python3 - "$file_path" <<'PY'
import json
import sys

print(json.dumps({
    "session_id": "image-hook-test",
    "hook_event_name": "PreToolUse",
    "tool_name": "Read",
    "tool_input": {"file_path": sys.argv[1]},
    "tool_use_id": "call_image_hook",
}, separators=(",", ":")))
PY
}

payload_for_write() {
  local file_path
  file_path="$1"

  python3 - "$file_path" <<'PY'
import json
import sys

print(json.dumps({
    "session_id": "image-hook-test",
    "hook_event_name": "PreToolUse",
    "tool_name": "Write",
    "tool_input": {"file_path": sys.argv[1], "content": "not read"},
    "tool_use_id": "call_image_hook_write",
}, separators=(",", ":")))
PY
}

run_hook() {
  local payload
  local vision_stub
  payload="$1"
  vision_stub="$2"

  set +e
  RUN_STDOUT="$(ALBION_VISION_BIN="$vision_stub" ALBION_IMAGE_LOG="${TMP_DIR}/image.log" bash "$HOOK" <<<"$payload")"
  RUN_CODE=$?
  set -e
}

run_hook_with_mode() {
  local payload
  local vision_stub
  local mode
  payload="$1"
  vision_stub="$2"
  mode="$3"

  set +e
  RUN_STDOUT="$(ALBION_STUB_VISION_MODE="$mode" ALBION_VISION_BIN="$vision_stub" ALBION_IMAGE_LOG="${TMP_DIR}/image.log" ALBION_ZAI_TOKEN="super-secret-token" bash "$HOOK" <<<"$payload")"
  RUN_CODE=$?
  set -e
}

reason_from_output() {
  python3 -c '
import json
import sys

payload = json.load(sys.stdin)
hook_output = payload["hookSpecificOutput"]
assert hook_output["hookEventName"] == "PreToolUse"
assert hook_output["permissionDecision"] == "deny"
print(hook_output["permissionDecisionReason"])
'
}

description_length() {
  local reason
  local file_path
  reason="$1"
  file_path="$2"

  python3 - "$reason" "$file_path" <<'PY'
import sys

reason, file_path = sys.argv[1:3]
prefix = f"Image read intercepted. Vision description of {file_path}: "
description = reason.split(prefix, 1)[1].split("\nRaw image bytes were not loaded.", 1)[0]
print(len(description))
PY
}

assert_json_output() {
  local output
  output="$1"

  if [ -z "$output" ]; then
    return
  fi

  python3 - "$output" <<'PY'
import json
import sys

for line in sys.argv[1].splitlines():
    json.loads(line)
PY
}

assert_image_denies_with_description() {
  local file_path
  local payload
  local reason
  local vision_stub
  file_path="$1"
  vision_stub="$2"
  payload="$(payload_for_read "$file_path")"

  run_hook "$payload" "$vision_stub"
  assert_exit_code 0 "$RUN_CODE" "image read should exit zero"
  assert_json_output "$RUN_STDOUT"
  reason="$(printf '%s' "$RUN_STDOUT" | reason_from_output)"
  assert_contains "$reason" "Image read intercepted. Vision description of ${file_path}: stub description for ${file_path}" "supported image should include stub description"
  assert_contains "$reason" "Raw image bytes were not loaded." "supported image should note raw bytes were blocked"
}

test_supported_images_are_denied_with_vision_description() {
  local vision_stub
  vision_stub="$(make_vision_stub)"

  assert_image_denies_with_description "${TMP_DIR}/sample.png" "$vision_stub"
  assert_image_denies_with_description "${TMP_DIR}/sample.jpg" "$vision_stub"
  assert_image_denies_with_description "${TMP_DIR}/sample.JPEG" "$vision_stub"
}

test_non_images_are_silent_noops() {
  local vision_stub
  local payload
  vision_stub="$(make_vision_stub)"

  payload="$(payload_for_read "${TMP_DIR}/script.py")"
  run_hook "$payload" "$vision_stub"
  assert_exit_code 0 "$RUN_CODE" "python read should exit zero"
  assert_eq "" "$RUN_STDOUT" "python read should emit no output"

  payload="$(payload_for_read "${TMP_DIR}/README")"
  run_hook "$payload" "$vision_stub"
  assert_exit_code 0 "$RUN_CODE" "extensionless read should exit zero"
  assert_eq "" "$RUN_STDOUT" "extensionless read should emit no output"
}

test_other_tools_are_silent_noops() {
  local vision_stub
  local payload
  vision_stub="$(make_vision_stub)"
  payload="$(payload_for_write "${TMP_DIR}/write.png")"

  run_hook "$payload" "$vision_stub"
  assert_exit_code 0 "$RUN_CODE" "other tool should exit zero"
  assert_eq "" "$RUN_STDOUT" "other tool should emit no output"
}

test_unsupported_image_type_denies_without_guessing() {
  local vision_stub
  local payload
  local reason
  vision_stub="$(make_vision_stub)"
  payload="$(payload_for_read "${TMP_DIR}/animation.gif")"

  run_hook "$payload" "$vision_stub"
  assert_exit_code 0 "$RUN_CODE" "gif read should exit zero"
  assert_json_output "$RUN_STDOUT"
  reason="$(printf '%s' "$RUN_STDOUT" | reason_from_output)"
  assert_contains "$reason" "vision subsystem cannot describe ${TMP_DIR}/animation.gif (.gif)" "gif should report unsupported type"
  assert_contains "$reason" "do not guess its content" "gif should forbid guessing"
}

test_vision_failure_denies_with_degrade_note() {
  local vision_stub
  local payload
  local reason
  vision_stub="$(make_vision_stub)"
  payload="$(payload_for_read "${TMP_DIR}/missing-provider.png")"

  run_hook_with_mode "$payload" "$vision_stub" fail
  assert_exit_code 0 "$RUN_CODE" "vision failure should exit zero"
  assert_json_output "$RUN_STDOUT"
  reason="$(printf '%s' "$RUN_STDOUT" | reason_from_output)"
  assert_contains "$reason" "no vision provider available for ${TMP_DIR}/missing-provider.png; do not guess image content" "failure should degrade factually"
}

test_oversized_description_is_truncated() {
  local vision_stub
  local file_path
  local payload
  local reason
  local length
  vision_stub="$(make_vision_stub)"
  file_path="${TMP_DIR}/large.png"
  payload="$(payload_for_read "$file_path")"

  run_hook_with_mode "$payload" "$vision_stub" oversized
  assert_exit_code 0 "$RUN_CODE" "oversized description should exit zero"
  assert_json_output "$RUN_STDOUT"
  reason="$(printf '%s' "$RUN_STDOUT" | reason_from_output)"
  assert_contains "$reason" "[truncated to 4000 characters]" "oversized description should include truncation marker"
  length="$(description_length "$reason" "$file_path")"
  assert_eq "4000" "$length" "truncated description should be capped at 4000 characters"
}

test_malformed_stdin_is_silent_noop() {
  local vision_stub
  vision_stub="$(make_vision_stub)"

  run_hook "{not json" "$vision_stub"
  assert_exit_code 0 "$RUN_CODE" "malformed stdin should exit zero"
  assert_eq "" "$RUN_STDOUT" "malformed stdin should be silent"
}

test_missing_vision_binary_denies_with_degrade_note() {
  local payload
  local reason
  payload="$(payload_for_read "${TMP_DIR}/missing-bin.png")"

  run_hook "$payload" "${TMP_DIR}/does-not-exist"
  assert_exit_code 0 "$RUN_CODE" "missing vision binary should exit zero"
  assert_json_output "$RUN_STDOUT"
  reason="$(printf '%s' "$RUN_STDOUT" | reason_from_output)"
  assert_contains "$reason" "no vision provider available for ${TMP_DIR}/missing-bin.png; do not guess image content" "missing binary should degrade factually"
}

test_sensitive_env_values_are_not_emitted() {
  local vision_stub
  local payload
  local reason
  vision_stub="$(make_vision_stub)"
  payload="$(payload_for_read "${TMP_DIR}/secret.png")"

  run_hook_with_mode "$payload" "$vision_stub" token
  assert_exit_code 0 "$RUN_CODE" "token echo mode should exit zero"
  assert_json_output "$RUN_STDOUT"
  reason="$(printf '%s' "$RUN_STDOUT" | reason_from_output)"
  assert_contains "$reason" "[REDACTED]" "sensitive value should be redacted"
  case "$reason" in
    *"super-secret-token"*) assert_fail "deny reason must not include raw token value" ;;
  esac
}

test_supported_images_are_denied_with_vision_description
test_non_images_are_silent_noops
test_other_tools_are_silent_noops
test_unsupported_image_type_denies_without_guessing
test_vision_failure_denies_with_degrade_note
test_oversized_description_is_truncated
test_malformed_stdin_is_silent_noop
test_missing_vision_binary_denies_with_degrade_note
test_sensitive_env_values_are_not_emitted
