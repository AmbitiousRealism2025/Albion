#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/albion-plugin-manifest.XXXXXX")"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

validate_plugin_json() {
  local plugin_json

  plugin_json="${ROOT_DIR}/plugin/.claude-plugin/plugin.json"
  assert_file_exists "$plugin_json" "plugin manifest should exist"

  python3 - "$plugin_json" <<'PY'
import json
import pathlib
import sys

plugin_json = pathlib.Path(sys.argv[1])
payload = json.loads(plugin_json.read_text(encoding="utf-8"))

assert isinstance(payload, dict), "plugin.json must contain a JSON object"
for field in ("name", "version"):
    value = payload.get(field)
    assert isinstance(value, str) and value.strip(), f"plugin.json {field} must be non-empty"
PY
}

run_doctor_manifest_check() {
  local doctor_output
  local doctor_stderr
  local exit_code
  local stub_dir

  stub_dir="${TMP_DIR}/bin"
  mkdir -p "$stub_dir"

  cat >"${stub_dir}/claude" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  printf 'Claude Code 2.1.200\n'
  exit 0
fi

printf 'stub claude invoked\n'
STUB
  chmod +x "${stub_dir}/claude"

  set +e
  doctor_output="$(
    env -i \
      TMPDIR="${TMPDIR:-/tmp}" \
      PATH="${stub_dir}:${PATH}" \
      ALBION_ZAI_TOKEN=test-token \
      "${ROOT_DIR}/bin/albion-doctor" --offline \
      2>"${TMP_DIR}/doctor.err"
  )"
  exit_code=$?
  set -e
  doctor_stderr="$(cat "${TMP_DIR}/doctor.err")"

  assert_exit_code 0 "$exit_code" "offline doctor should pass with manifest check"
  assert_eq "" "$doctor_stderr" "offline doctor should not write stderr"
  assert_contains "$doctor_output" "PASS manifest: charter in sync; 5 skills, 5 agents, plugin.json ok" "doctor manifest check should pass"
}

validate_plugin_json
run_doctor_manifest_check
