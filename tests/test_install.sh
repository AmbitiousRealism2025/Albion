#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-install.$$"
PATH_FARM_TOOLS="bash sh python3 curl git dirname readlink rm ln mkdir chmod cat grep sed"

cd "$ROOT_DIR"
# shellcheck disable=SC1091
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

make_path_farm() {
  local name
  local include_python
  local farm_dir
  local tool
  local tool_path

  name="$1"
  include_python="$2"
  farm_dir="${TMP_DIR}/${name}-bin"
  mkdir -p "$farm_dir"

  for tool in $PATH_FARM_TOOLS; do
    if [ "$tool" = "python3" ] && [ "$include_python" = "no" ]; then
      continue
    fi

    if ! tool_path="$(command -v "$tool")"; then
      printf 'required test tool not found on host PATH: %s\n' "$tool" >&2
      exit 1
    fi
    ln -s "$tool_path" "${farm_dir}/${tool}"
  done

  cat >"${farm_dir}/claude" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
  printf 'Claude Code %s\n' "${CLAUDE_STUB_VERSION:?}"
  exit 0
fi

printf 'stub claude invoked\n'
STUB
  chmod +x "${farm_dir}/claude"
  printf '%s\n' "$farm_dir"
}

run_install() {
  local name
  local out_file
  local err_file

  name="$1"
  shift
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  env -i TMPDIR="${TMPDIR:-/tmp}" HOME="${TMP_DIR}/home" PATH="$RUN_PATH" "${RUN_ENV[@]}" \
    bash "${ROOT_DIR}/install.sh" "$@" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
}

resolved_path() {
  python3 - "$1" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
}

assert_tool_symlink() {
  local prefix
  local tool_name
  local link_path
  local expected_target
  local actual_target

  prefix="$1"
  tool_name="$2"
  link_path="${prefix}/${tool_name}"
  expected_target="${ROOT_DIR}/bin/${tool_name}"

  if [ ! -L "$link_path" ]; then
    assert_fail "${tool_name} should be installed as a symlink"
    return 1
  fi

  actual_target="$(resolved_path "$link_path")"
  assert_eq "$expected_target" "$actual_target" "${tool_name} resolves to repo bin"
}

RUN_ENV=()
RUN_PATH="$(make_path_farm install 2.1.200)"
prefix="$(resolved_path "${TMP_DIR}/prefix")"
RUN_ENV=("CLAUDE_STUB_VERSION=2.1.200")
run_install "first" --prefix "$prefix" --no-doctor
assert_exit_code 0 "$RUN_CODE" "first install succeeds"
assert_contains "$RUN_STDOUT" "Installed ${prefix}/albion -> ${ROOT_DIR}/bin/albion" "albion install is reported"
assert_contains "$RUN_STDOUT" "ALBION_ZAI_TOKEN" "plan token guidance is printed"
assert_contains "$RUN_STDOUT" "ALBION_ZAI_API_KEY" "api token guidance is printed"
assert_not_contains "$RUN_STDERR" "WARN:" "preferred claude version produces no warning"

for tool_name in albion albion-doctor albion-vision albion-compile; do
  assert_tool_symlink "$prefix" "$tool_name"
done

run_install "second" --prefix "$prefix" --no-doctor
assert_exit_code 0 "$RUN_CODE" "second install is idempotent"
for tool_name in albion albion-doctor albion-vision albion-compile; do
  assert_tool_symlink "$prefix" "$tool_name"
done

run_install "help" --help
assert_exit_code 0 "$RUN_CODE" "help exits zero"
assert_contains "$RUN_STDOUT" "Usage: ./install.sh" "help prints usage"

RUN_PATH="$(make_path_farm no-python no)"
RUN_ENV=("CLAUDE_STUB_VERSION=2.1.200")
run_install "missing-python" --prefix "${TMP_DIR}/missing-python" --no-doctor
assert_exit_code 1 "$RUN_CODE" "missing python3 fails"
assert_contains "$RUN_STDERR" "python3 not found on PATH" "missing python3 names the fix"

RUN_PATH="$(make_path_farm old-claude yes)"
RUN_ENV=("CLAUDE_STUB_VERSION=2.1.150")
run_install "old-claude" --prefix "${TMP_DIR}/old-claude" --no-doctor
assert_exit_code 1 "$RUN_CODE" "old claude fails"
assert_contains "$RUN_STDERR" "Claude Code 2.1.150 is below 2.1.163" "old claude names the minimum"

install_source="$(cat "${ROOT_DIR}/install.sh")"
zai_lines="$(grep 'ALBION_ZAI' "${ROOT_DIR}/install.sh")"
token_expansion="\${ALBION_ZAI"
token_read="\$ALBION_ZAI"
assert_contains "$zai_lines" "printf '  export ALBION_ZAI_TOKEN" "plan token appears only in printed guidance"
assert_contains "$zai_lines" "ALBION_ZAI_API_KEY" "api token appears only in printed guidance"
assert_not_contains "$install_source" "$token_expansion" "installer never expands ALBION_ZAI variables"
assert_not_contains "$install_source" "$token_read" "installer never reads ALBION_ZAI variables"
