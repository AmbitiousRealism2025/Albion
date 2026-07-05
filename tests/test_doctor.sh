#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-doctor.$$"
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

make_claude_path() {
  local name
  local version
  local stub_dir
  local tool
  local tool_path

  name="$1"
  version="$2"
  stub_dir="${TMP_DIR}/${name}-bin"
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
  printf '%s\n' "$stub_dir"
  printf '%s\n' "$version" >"${stub_dir}/version"
}

copy_path_with_tmux() {
  local source_dir
  local name
  local tmux_dir
  local entry
  local entry_name
  local target

  source_dir="$1"
  name="$2"
  tmux_dir="${TMP_DIR}/${name}-bin"
  mkdir -p "$tmux_dir"

  for entry in "$source_dir"/*; do
    entry_name="$(basename "$entry")"
    if target="$(readlink "$entry")" && [ -n "$target" ] && [ -e "$target" ]; then
      ln -s "$target" "${tmux_dir}/${entry_name}"
    else
      ln -s "$entry" "${tmux_dir}/${entry_name}"
    fi
  done

  cat >"${tmux_dir}/tmux" <<'STUB'
#!/usr/bin/env bash
printf 'tmux stub\n'
STUB
  chmod +x "${tmux_dir}/tmux"
  printf '%s\n' "$tmux_dir"
}

make_curl_stub() {
  local path

  path="${TMP_DIR}/curl-stub"
  cat >"$path" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

record_file="${ALBION_CURL_RECORD:?}"
scenario="${ALBION_CURL_SCENARIO:?}"
payload=""
url=""
previous=""

for arg in "$@"; do
  if [ "$previous" = "--data" ] || [ "$previous" = "--data-binary" ]; then
    payload="$arg"
    case "$payload" in
      @*) payload="$(cat "${payload#@}")" ;;
    esac
  fi
  case "$arg" in
    http*) url="$arg" ;;
  esac
  previous="$arg"
done

{
  printf 'url=%s\n' "$url"
  printf 'payload=%s\n' "$payload"
} >>"$record_file"

case "$scenario" in
  success)
    # The real endpoint serves two request shapes: the 1-token text probe and
    # the doctor's vision probe (model glm-4.6v, Anthropic messages format).
    case "$payload" in
      *glm-4.6v*)
        printf '{"content":[{"type":"text","text":"probe image described"}]}\n200'
        ;;
      *)
        printf '{"model":"glm-5.2"}\n200'
        ;;
    esac
    ;;
  wrong-model)
    printf '{"model":"not-glm"}\n200'
    ;;
  unauthorized)
    printf '{"error":{"message":"bad token"}}\n401'
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

run_doctor() {
  local name
  local out_file
  local err_file

  name="$1"
  shift
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  env -i TMPDIR="${TMPDIR:-/tmp}" PATH="$RUN_PATH" "${RUN_ENV[@]}" \
    "${ROOT_DIR}/bin/albion-doctor" "$@" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
}

run_launcher_doctor() {
  local name
  local out_file
  local err_file

  name="$1"
  shift
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  env -i TMPDIR="${TMPDIR:-/tmp}" PATH="$RUN_PATH" "${RUN_ENV[@]}" \
    bash "${ROOT_DIR}/bin/albion" --doctor "$@" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
}

curl_stub="$(make_curl_stub)"

stub_path_150="$(make_claude_path version-fail 2.1.150)"
RUN_PATH="$stub_path_150"
RUN_ENV=("ALBION_ZAI_TOKEN=test-token" "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-fail-bin/version")")
run_doctor "version-fail" --offline
assert_exit_code 1 "$RUN_CODE" "Claude Code 2.1.150 fails the minimum gate"
assert_contains "$RUN_STDOUT" "FAIL claude-version: Claude Code 2.1.150 is below 2.1.163" "minimum version failure is reported"
assert_contains "$RUN_STDOUT" "8 pass, 1 fail, 1 warn, 0 skip" "version failure summary counts"

stub_path_170="$(make_claude_path version-warn 2.1.170)"
RUN_PATH="$stub_path_170"
RUN_ENV=("ALBION_ZAI_TOKEN=test-token" "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-warn-bin/version")")
run_doctor "version-warn" --offline
assert_exit_code 0 "$RUN_CODE" "Claude Code 2.1.170 warns but exits zero"
assert_contains "$RUN_STDOUT" "WARN claude-version: Claude Code 2.1.170 meets minimum 2.1.163" "preferred version warning is reported"
assert_contains "$RUN_STDOUT" "8 pass, 0 fail, 2 warn, 0 skip" "version warning summary counts"

stub_path_200="$(make_claude_path version-pass 2.1.200)"
RUN_PATH="$stub_path_200"
RUN_ENV=("ALBION_ZAI_TOKEN=test-token" "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-pass-bin/version")")
run_doctor "version-pass" --offline
assert_exit_code 0 "$RUN_CODE" "Claude Code 2.1.200 passes"
assert_contains "$RUN_STDOUT" "PASS claude-version: Claude Code 2.1.200" "preferred version pass is reported"
assert_contains "$RUN_STDOUT" "9 pass, 0 fail, 1 warn, 0 skip" "version pass summary counts"
assert_contains "$RUN_STDOUT" "PASS env: lane=plan token=***set***" "env check masks token state"
assert_contains "$RUN_STDOUT" "PASS endpoint-shape: https://api.z.ai/api/anthropic" "endpoint shape pass is reported"
assert_contains "$RUN_STDOUT" "WARN tmux: tmux not found on PATH; conductor features unavailable" "tmux absence warning is deterministic"
assert_contains "$RUN_STDOUT" "PASS hook-suite: PASS hook verification" "hook suite verification is reported"
assert_not_contains "$RUN_STDOUT" "test-token" "offline output never prints the token"
assert_not_contains "$RUN_STDERR" "test-token" "offline stderr never prints the token"

stub_path_200_tmux="$(copy_path_with_tmux "$stub_path_200" version-pass-tmux)"
RUN_PATH="$stub_path_200_tmux"
RUN_ENV=("ALBION_ZAI_TOKEN=test-token" "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-pass-bin/version")")
run_doctor "version-pass-tmux" --offline
assert_exit_code 0 "$RUN_CODE" "Claude Code 2.1.200 passes when tmux is present"
assert_contains "$RUN_STDOUT" "PASS tmux: ${stub_path_200_tmux}/tmux" "tmux presence pass is deterministic"
assert_contains "$RUN_STDOUT" "10 pass, 0 fail, 0 warn, 0 skip" "tmux presence summary counts"

RUN_PATH="$stub_path_200"
RUN_ENV=(
  "ALBION_ZAI_TOKEN=test-token"
  "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-pass-bin/version")"
  "ALBION_DOCTOR_BASE_URL_OVERRIDE=https://api.z.ai/api/paas/v4"
)
run_doctor "endpoint-fail" --offline
assert_exit_code 1 "$RUN_CODE" "wrong endpoint shape fails"
assert_contains "$RUN_STDOUT" "FAIL endpoint-shape: ANTHROPIC_BASE_URL=https://api.z.ai/api/paas/v4" "endpoint failure reports actual value"
assert_contains "$RUN_STDOUT" "documented trap /api/paas/v4" "endpoint failure names documented trap"
assert_contains "$RUN_STDOUT" "8 pass, 1 fail, 1 warn, 0 skip" "endpoint failure summary counts"

curl_record="${TMP_DIR}/curl-success.record"
: >"$curl_record"
RUN_PATH="$stub_path_200"
RUN_ENV=(
  "ALBION_ZAI_TOKEN=secret-token"
  "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-pass-bin/version")"
  "ALBION_DOCTOR_CURL=${curl_stub}"
  "ALBION_CURL_SCENARIO=success"
  "ALBION_CURL_RECORD=${curl_record}"
)
run_doctor "live-success" --live
assert_exit_code 0 "$RUN_CODE" "live probe accepts glm-5.2 response"
assert_contains "$RUN_STDOUT" "PASS live-probe: HTTP 200 model=glm-5.2" "live success reports response model"
assert_contains "$RUN_STDOUT" "10 pass, 0 fail, 1 warn, 0 skip" "live success summary counts"
assert_contains "$(cat "$curl_record")" "url=https://api.z.ai/api/anthropic/v1/messages" "live probe posts to messages endpoint"
assert_contains "$(cat "$curl_record")" '"model":"glm-5.2"' "live probe strips [1m] suffix from model"
assert_not_contains "$RUN_STDOUT" "secret-token" "live success stdout never prints token"
assert_not_contains "$RUN_STDERR" "secret-token" "live success stderr never prints token"

curl_record="${TMP_DIR}/curl-wrong.record"
: >"$curl_record"
RUN_ENV=(
  "ALBION_ZAI_TOKEN=secret-token"
  "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-pass-bin/version")"
  "ALBION_DOCTOR_CURL=${curl_stub}"
  "ALBION_CURL_SCENARIO=wrong-model"
  "ALBION_CURL_RECORD=${curl_record}"
)
run_doctor "live-wrong-model" --live
assert_exit_code 1 "$RUN_CODE" "live probe fails wrong model"
assert_contains "$RUN_STDOUT" "FAIL live-probe: HTTP 200 model=not-glm" "wrong model is reported"
assert_contains "$RUN_STDOUT" "possible silent slot remap" "wrong model names silent remap hazard"
assert_contains "$RUN_STDOUT" "8 pass, 2 fail, 1 warn, 0 skip" "wrong model summary counts"

curl_record="${TMP_DIR}/curl-401.record"
: >"$curl_record"
RUN_ENV=(
  "ALBION_ZAI_TOKEN=secret-token"
  "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-pass-bin/version")"
  "ALBION_DOCTOR_CURL=${curl_stub}"
  "ALBION_CURL_SCENARIO=unauthorized"
  "ALBION_CURL_RECORD=${curl_record}"
)
run_doctor "live-401" --live
assert_exit_code 1 "$RUN_CODE" "live probe fails non-200"
assert_contains "$RUN_STDOUT" "FAIL live-probe: HTTP 401: bad token" "non-200 includes parseable error message"
assert_not_contains "$RUN_STDOUT" "secret-token" "non-200 stdout never prints token"
assert_not_contains "$RUN_STDERR" "secret-token" "non-200 stderr never prints token"

RUN_ENV=("CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-pass-bin/version")")
run_doctor "live-missing-token" --live
assert_exit_code 1 "$RUN_CODE" "missing token still reports env failure"
assert_contains "$RUN_STDOUT" "FAIL env:" "missing token fails env check"
assert_contains "$RUN_STDOUT" "SKIP live-probe: env did not load; no token resolves" "missing token skips live probe"
assert_contains "$RUN_STDOUT" "6 pass, 1 fail, 1 warn, 3 skip" "missing token summary counts"

RUN_ENV=("ALBION_ZAI_TOKEN=test-token" "CLAUDE_STUB_VERSION=$(cat "${TMP_DIR}/version-pass-bin/version")")
run_doctor "usage-error" --bogus
assert_exit_code 2 "$RUN_CODE" "unknown doctor flag exits 2"
assert_contains "$RUN_STDERR" "unknown flag: --bogus" "usage error names bad flag"

run_doctor "help" --help
assert_exit_code 0 "$RUN_CODE" "help exits zero"
assert_contains "$RUN_STDOUT" "Usage: albion-doctor" "help prints usage"

run_launcher_doctor "launcher-delegates" --offline
assert_exit_code 0 "$RUN_CODE" "bin/albion --doctor delegates to installed doctor"
assert_contains "$RUN_STDOUT" "PASS env:" "delegated doctor emits health checks"
