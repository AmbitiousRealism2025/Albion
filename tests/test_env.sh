#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-env.$$"

. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

run_source_capture() {
  local name
  local setup
  local body
  local out_file
  local err_file
  name="$1"
  setup="$2"
  body="${3:-env | sort}"
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  env -i PATH="${PATH}" TMPDIR="${TMPDIR:-/tmp}" \
    bash -c "${setup}; source \"${ROOT_DIR}/env/albion-env.sh\" && ${body}" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
}

assert_export() {
  local output
  local name
  local expected
  output="$1"
  name="$2"
  expected="$3"

  assert_contains "$output" "${name}=${expected}" "${name} export"
}

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

assert_common_exports() {
  local output
  local token
  output="$1"
  token="$2"

  assert_export "$output" "ALBION_ENV_LOADED" "1"
  assert_export "$output" "ANTHROPIC_BASE_URL" "https://api.z.ai/api/anthropic"
  assert_export "$output" "ANTHROPIC_AUTH_TOKEN" "$token"
  assert_export "$output" "ANTHROPIC_DEFAULT_OPUS_MODEL" "glm-5.2[1m]"
  assert_export "$output" "ANTHROPIC_DEFAULT_SONNET_MODEL" "glm-5.2[1m]"
  assert_export "$output" "ANTHROPIC_DEFAULT_HAIKU_MODEL" "glm-5-turbo"
  assert_export "$output" "API_TIMEOUT_MS" "3000000"
  assert_export "$output" "CLAUDE_CODE_AUTO_COMPACT_WINDOW" "1000000"
  assert_export "$output" "CLAUDE_CODE_MAX_OUTPUT_TOKENS" "131072"
  assert_export "$output" "CLAUDE_CODE_ATTRIBUTION_HEADER" "0"
  assert_export "$output" "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" "1"
  assert_export "$output" "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB" "1"
  assert_export "$output" "CLAUDE_CODE_STOP_HOOK_BLOCK_CAP" "4"
  assert_not_contains "$output" "ANTHROPIC_MODEL=" "script does not set ANTHROPIC_MODEL"
  assert_not_contains "$output" "MAX_THINKING_TOKENS=" "script does not set MAX_THINKING_TOKENS"
  assert_not_contains "$output" "CLAUDE_CODE_EFFORT_LEVEL=" "script does not set CLAUDE_CODE_EFFORT_LEVEL"
}

run_source_capture "plan" 'export ALBION_ZAI_PLAN_TOKEN=plan-token'
assert_exit_code 0 "$RUN_CODE" "plan lane sources successfully"
assert_eq "" "$RUN_STDERR" "plan lane is stderr-quiet"
assert_export "$RUN_STDOUT" "ALBION_AUTH_LANE" "plan"
assert_common_exports "$RUN_STDOUT" "plan-token"

run_source_capture "api" 'export ALBION_AUTH_LANE=api ALBION_ZAI_API_KEY=api-token'
assert_exit_code 0 "$RUN_CODE" "api lane sources successfully"
assert_eq "" "$RUN_STDERR" "api lane is stderr-quiet"
assert_export "$RUN_STDOUT" "ALBION_AUTH_LANE" "api"
assert_common_exports "$RUN_STDOUT" "api-token"

run_source_capture "quiet-success" 'export ALBION_ZAI_PLAN_TOKEN=plan-token' ':'
assert_exit_code 0 "$RUN_CODE" "successful source without a body succeeds"
assert_eq "" "$RUN_STDOUT" "successful source is stdout-quiet"
assert_eq "" "$RUN_STDERR" "successful source is stderr-quiet"

run_source_capture "plan-fallback" 'export ALBION_ZAI_TOKEN=fallback-token'
assert_exit_code 0 "$RUN_CODE" "plan lane fallback token succeeds"
assert_export "$RUN_STDOUT" "ALBION_AUTH_LANE" "plan"
assert_export "$RUN_STDOUT" "ANTHROPIC_AUTH_TOKEN" "fallback-token"

run_source_capture "api-fallback" 'export ALBION_AUTH_LANE=api ALBION_ZAI_TOKEN=fallback-token'
assert_exit_code 0 "$RUN_CODE" "api lane fallback token succeeds"
assert_export "$RUN_STDOUT" "ALBION_AUTH_LANE" "api"
assert_export "$RUN_STDOUT" "ANTHROPIC_AUTH_TOKEN" "fallback-token"

run_source_capture "effort-failure" 'export CLAUDE_CODE_EFFORT_LEVEL=high ALBION_ZAI_PLAN_TOKEN=plan-token'
assert_exit_code 1 "$RUN_CODE" "effort override fails"
assert_eq "" "$RUN_STDOUT" "effort failure is stdout-quiet"
assert_contains "$RUN_STDERR" "CLAUDE_CODE_EFFORT_LEVEL" "effort failure names variable"
assert_contains "$RUN_STDERR" "unset CLAUDE_CODE_EFFORT_LEVEL" "effort failure includes remedy"

run_source_capture "token-failure" 'true'
assert_exit_code 1 "$RUN_CODE" "missing token fails"
assert_eq "" "$RUN_STDOUT" "token failure is stdout-quiet"
assert_contains "$RUN_STDERR" "ALBION_ZAI_PLAN_TOKEN" "token failure names lane token"
assert_contains "$RUN_STDERR" "ALBION_ZAI_TOKEN" "token failure names fallback token"

run_source_capture "lane-failure" 'export ALBION_AUTH_LANE=bogus ALBION_ZAI_TOKEN=fallback-token'
assert_exit_code 1 "$RUN_CODE" "invalid lane fails"
assert_eq "" "$RUN_STDOUT" "lane failure is stdout-quiet"
assert_contains "$RUN_STDERR" "ALBION_AUTH_LANE" "lane failure names variable"
assert_contains "$RUN_STDERR" "ALBION_AUTH_LANE=plan" "lane failure includes plan remedy"
assert_contains "$RUN_STDERR" "ALBION_AUTH_LANE=api" "lane failure includes api remedy"

run_source_capture "overrides" 'export ALBION_ZAI_PLAN_TOKEN=plan-token ALBION_ALLOW_OVERRIDES=1 ANTHROPIC_DEFAULT_OPUS_MODEL=custom-opus ANTHROPIC_DEFAULT_SONNET_MODEL=custom-sonnet ANTHROPIC_DEFAULT_HAIKU_MODEL=custom-haiku'
assert_exit_code 0 "$RUN_CODE" "override lane sources successfully"
assert_export "$RUN_STDOUT" "ANTHROPIC_DEFAULT_OPUS_MODEL" "custom-opus"
assert_export "$RUN_STDOUT" "ANTHROPIC_DEFAULT_SONNET_MODEL" "custom-sonnet"
assert_export "$RUN_STDOUT" "ANTHROPIC_DEFAULT_HAIKU_MODEL" "custom-haiku"

run_source_capture "double-source" \
  'export ALBION_ZAI_PLAN_TOKEN=first-token' \
  'source "'"${ROOT_DIR}"'/env/albion-env.sh" && env | sort'
assert_exit_code 0 "$RUN_CODE" "double source succeeds"
assert_eq "" "$RUN_STDERR" "double source is stderr-quiet"
assert_export "$RUN_STDOUT" "ALBION_ENV_LOADED" "1"
assert_export "$RUN_STDOUT" "ANTHROPIC_AUTH_TOKEN" "first-token"
