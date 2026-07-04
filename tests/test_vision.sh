#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/albion-test-vision.XXXXXX")"
STUB_TOKEN="stub-secret-token"

cd "$ROOT_DIR"
# shellcheck disable=SC1091
. tests/lib/assert.sh

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

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

make_png() {
  local path

  path="$1"
  python3 - "$path" <<'PY'
import base64
import pathlib
import sys

png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(png))
PY
}

make_curl_stub() {
  local path

  path="${TMP_DIR}/curl-stub"
  cat >"$path" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

record_file="${ALBION_CURL_RECORD:?}"
scenario="${ALBION_CURL_SCENARIO:?}"
url=""
payload=""
headers_file="${record_file}.headers"
previous=""

: >"$headers_file"

for arg in "$@"; do
  if [ "$previous" = "--header" ]; then
    printf 'header=%s\n' "$arg" >>"$headers_file"
  elif [ "$previous" = "--data-binary" ]; then
    case "$arg" in
      @*) payload="$(cat "${arg#@}")" ;;
      *) payload="$arg" ;;
    esac
  fi
  case "$arg" in
    http*) url="$arg" ;;
  esac
  previous="$arg"
done

{
  printf 'url=%s\n' "$url"
  cat "$headers_file"
  printf 'payload=%s\n' "$payload"
} >>"$record_file"

case "$scenario" in
  plan-success)
    printf '{"content":[{"type":"text","text":"plan description text"}]}\n200'
    ;;
  api-success)
    printf '{"choices":[{"message":{"content":"api description text"}}]}\n200'
    ;;
  coding-plan-token)
    printf '{"error":{"code":"1113","message":"Insufficient balance"}}\n429'
    ;;
  unknown-model)
    printf '{"error":{"code":"1211","message":"unknown model"}}\n400'
    ;;
  doctor-live)
    if printf '%s' "$payload" | grep -q '"model":"glm-4.6v"'; then
      printf '{"content":[{"type":"text","text":"doctor vision probe"}]}\n200'
    else
      printf '{"model":"glm-5.2"}\n200'
    fi
    ;;
  *)
    printf 'unknown curl scenario: %s\n' "$scenario" >&2
    exit 9
    ;;
esac
STUB
  chmod +x "$path"
  printf '%s\n' "$path"
}

run_vision() {
  local name
  local out_file
  local err_file

  name="$1"
  shift
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  env -i TMPDIR="${TMPDIR:-/tmp}" PATH="$PATH" "$@" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
}

assert_plan_payload() {
  local record

  record="$1"
  python3 - "$record" <<'PY'
import json
import pathlib
import sys

record = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
payload_line = next(line for line in record.splitlines() if line.startswith("payload="))
payload = json.loads(payload_line[len("payload="):])

assert payload["model"] == "glm-4.6v"
content = payload["messages"][0]["content"]
assert content[0]["type"] == "image"
assert content[0]["source"]["type"] == "base64"
assert content[0]["source"]["media_type"] == "image/png"
assert content[0]["source"]["data"]
assert content[1] == {"type": "text", "text": "Describe this image factually and completely."}
PY
}

assert_api_payload() {
  local record

  record="$1"
  python3 - "$record" <<'PY'
import json
import pathlib
import sys

record = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
payload_line = next(line for line in record.splitlines() if line.startswith("payload="))
payload = json.loads(payload_line[len("payload="):])

assert payload["model"] == "glm-4.6v-flash"
content = payload["messages"][0]["content"]
assert content[0] == {"type": "text", "text": "What color is it?"}
assert content[1]["type"] == "image_url"
assert content[1]["image_url"]["url"].startswith("data:image/png;base64,")
PY
}

image_path="${TMP_DIR}/pixel.png"
make_png "$image_path"
curl_stub="$(make_curl_stub)"

curl_record="${TMP_DIR}/plan.record"
: >"$curl_record"
run_vision "plan-success" \
  ALBION_ZAI_PLAN_TOKEN="$STUB_TOKEN" \
  ALBION_VISION_CURL="$curl_stub" \
  ALBION_CURL_RECORD="$curl_record" \
  ALBION_CURL_SCENARIO=plan-success \
  "${ROOT_DIR}/bin/albion-vision" "$image_path"
assert_exit_code 0 "$RUN_CODE" "plan lane vision call succeeds"
assert_eq "plan description text" "$RUN_STDOUT" "successful plan call prints exactly the description"
assert_eq "" "$RUN_STDERR" "successful plan call does not write stderr"
assert_contains "$(cat "$curl_record")" "url=https://api.z.ai/api/anthropic/v1/messages" "plan lane uses anthropic endpoint"
assert_contains "$(cat "$curl_record")" "header=Authorization: Bearer ${STUB_TOKEN}" "plan lane sends bearer token"
assert_contains "$(cat "$curl_record")" "header=anthropic-version: 2023-06-01" "plan lane sends anthropic-version"
assert_plan_payload "$curl_record"
assert_not_contains "$RUN_STDOUT" "$STUB_TOKEN" "plan stdout never prints token"
assert_not_contains "$RUN_STDERR" "$STUB_TOKEN" "plan stderr never prints token"

curl_record="${TMP_DIR}/api.record"
: >"$curl_record"
run_vision "api-success" \
  ALBION_ZAI_API_KEY="$STUB_TOKEN" \
  ALBION_VISION_CURL="$curl_stub" \
  ALBION_CURL_RECORD="$curl_record" \
  ALBION_CURL_SCENARIO=api-success \
  "${ROOT_DIR}/bin/albion-vision" --lane api --model glm-4.6v-flash --prompt "What color is it?" "$image_path"
assert_exit_code 0 "$RUN_CODE" "api lane vision call succeeds"
assert_eq "api description text" "$RUN_STDOUT" "successful api call prints exactly the description"
assert_contains "$(cat "$curl_record")" "url=https://api.z.ai/api/paas/v4/chat/completions" "api lane uses paas endpoint"
assert_contains "$(cat "$curl_record")" "header=Authorization: Bearer ${STUB_TOKEN}" "api lane sends bearer token"
assert_not_contains "$(cat "$curl_record")" "anthropic-version" "api lane does not send anthropic-version"
assert_api_payload "$curl_record"
assert_not_contains "$RUN_STDOUT" "$STUB_TOKEN" "api stdout never prints token"
assert_not_contains "$RUN_STDERR" "$STUB_TOKEN" "api stderr never prints token"

curl_record="${TMP_DIR}/1113.record"
: >"$curl_record"
run_vision "coding-plan-token" \
  ALBION_ZAI_API_KEY="$STUB_TOKEN" \
  ALBION_VISION_CURL="$curl_stub" \
  ALBION_CURL_RECORD="$curl_record" \
  ALBION_CURL_SCENARIO=coding-plan-token \
  "${ROOT_DIR}/bin/albion-vision" --lane api "$image_path"
assert_exit_code 1 "$RUN_CODE" "1113 api lane response fails"
assert_contains "$RUN_STDERR" "this token appears to be a Coding Plan token" "1113 diagnostic explains plan token lane mismatch"
assert_contains "$RUN_STDERR" "plan tokens only work via --lane plan (/api/anthropic)" "1113 diagnostic names plan endpoint"
assert_not_contains "$RUN_STDOUT" "$STUB_TOKEN" "1113 stdout never prints token"
assert_not_contains "$RUN_STDERR" "$STUB_TOKEN" "1113 stderr never prints token"

curl_record="${TMP_DIR}/1211.record"
: >"$curl_record"
run_vision "unknown-model" \
  ALBION_ZAI_PLAN_TOKEN="$STUB_TOKEN" \
  ALBION_VISION_CURL="$curl_stub" \
  ALBION_CURL_RECORD="$curl_record" \
  ALBION_CURL_SCENARIO=unknown-model \
  "${ROOT_DIR}/bin/albion-vision" --model bad-vision "$image_path"
assert_exit_code 1 "$RUN_CODE" "1211 response fails"
assert_contains "$RUN_STDERR" "unknown model slug 'bad-vision'" "1211 diagnostic names requested slug"
assert_contains "$RUN_STDERR" "glm-4.6v" "1211 diagnostic suggests default model"
assert_not_contains "$RUN_STDOUT" "$STUB_TOKEN" "1211 stdout never prints token"
assert_not_contains "$RUN_STDERR" "$STUB_TOKEN" "1211 stderr never prints token"

run_vision "missing-file" \
  ALBION_ZAI_PLAN_TOKEN="$STUB_TOKEN" \
  ALBION_VISION_CURL="$curl_stub" \
  "${ROOT_DIR}/bin/albion-vision" "${TMP_DIR}/missing.png"
assert_exit_code 1 "$RUN_CODE" "missing image fails"
assert_contains "$RUN_STDERR" "image not found:" "missing image diagnostic is factual"
assert_not_contains "$RUN_STDERR" "$STUB_TOKEN" "missing file stderr never prints token"

text_path="${TMP_DIR}/note.txt"
printf 'not an image\n' >"$text_path"
run_vision "unsupported-extension" \
  ALBION_ZAI_PLAN_TOKEN="$STUB_TOKEN" \
  ALBION_VISION_CURL="$curl_stub" \
  "${ROOT_DIR}/bin/albion-vision" "$text_path"
assert_exit_code 1 "$RUN_CODE" "unsupported extension fails"
assert_contains "$RUN_STDERR" "unsupported image type" "unsupported type diagnostic is factual"
assert_not_contains "$RUN_STDERR" "$STUB_TOKEN" "unsupported type stderr never prints token"

large_path="${TMP_DIR}/large.png"
python3 - "$large_path" <<'PY'
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_bytes(b"0" * (5 * 1024 * 1024 + 1))
PY
run_vision "oversize" \
  ALBION_ZAI_PLAN_TOKEN="$STUB_TOKEN" \
  ALBION_VISION_CURL="$curl_stub" \
  "${ROOT_DIR}/bin/albion-vision" "$large_path"
assert_exit_code 1 "$RUN_CODE" "oversize image fails"
assert_contains "$RUN_STDERR" "image is larger than 5MB" "oversize diagnostic is factual"
assert_not_contains "$RUN_STDERR" "$STUB_TOKEN" "oversize stderr never prints token"

doctor_bin="${TMP_DIR}/doctor-bin"
mkdir -p "$doctor_bin"
cat >"${doctor_bin}/claude" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  printf 'Claude Code 2.1.200\n'
  exit 0
fi

printf 'stub claude invoked\n'
STUB
chmod +x "${doctor_bin}/claude"

doctor_output="$(
  env -i \
    TMPDIR="${TMPDIR:-/tmp}" \
    PATH="${doctor_bin}:${PATH}" \
    ALBION_ZAI_TOKEN="$STUB_TOKEN" \
    "${ROOT_DIR}/bin/albion-doctor" --offline
)"
assert_contains "$doctor_output" "PASS vision: lane=plan model=glm-4.6v token=***set***" "offline doctor reports vision check"
assert_not_contains "$doctor_output" "$STUB_TOKEN" "offline doctor vision check masks token"

curl_record="${TMP_DIR}/doctor-live.record"
: >"$curl_record"
doctor_output="$(
  env -i \
    TMPDIR="${TMPDIR:-/tmp}" \
    PATH="${doctor_bin}:${PATH}" \
    ALBION_ZAI_TOKEN="$STUB_TOKEN" \
    ALBION_DOCTOR_CURL="$curl_stub" \
    ALBION_CURL_RECORD="$curl_record" \
    ALBION_CURL_SCENARIO=doctor-live \
    "${ROOT_DIR}/bin/albion-doctor" --live
)"
assert_contains "$doctor_output" "PASS vision: lane=plan model=glm-4.6v live description received" "live doctor runs vision probe"
assert_not_contains "$doctor_output" "$STUB_TOKEN" "live doctor vision check masks token"
