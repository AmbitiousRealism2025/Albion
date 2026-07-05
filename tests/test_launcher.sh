#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-launcher.$$"
BASE_PATH="/usr/bin:/bin"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"
PLUGIN_DIR="$(cd -P "${ROOT_DIR}/plugin" && pwd)"
SETTINGS_PATH="$(cd -P "${ROOT_DIR}/config" && pwd)/albion-settings.json"

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

make_stub_path() {
  local name
  local stub_dir

  name="$1"
  stub_dir="${TMP_DIR}/${name}-bin"
  mkdir -p "$stub_dir"

  cat >"${stub_dir}/claude" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

record_file="${ALBION_STUB_RECORD:?}"
original_argv=("$@")
append_present=0

for arg in "${original_argv[@]}"; do
  if [ "$arg" = "--append-system-prompt" ]; then
    append_present=1
  fi
done

{
  printf 'agent=%s\n' "${CLAUDE_AGENT_NAME:-}"
  printf 'base_url=%s\n' "${ANTHROPIC_BASE_URL:-}"
  printf 'append_present=%s\n' "$append_present"
  printf 'argc=%s\n' "${#original_argv[@]}"
  for i in "${!original_argv[@]}"; do
    printf 'argv[%s]=%s\n' "$i" "${original_argv[$i]}"
  done
} >>"$record_file"
STUB
  chmod +x "${stub_dir}/claude"
  printf '%s:%s\n' "$stub_dir" "$BASE_PATH"
}

run_launcher() {
  local name
  local run_path
  local charter_mode
  local charter_value
  local token_mode
  local launcher_path
  local out_file
  local err_file
  local record_file
  local -a env_vars

  name="$1"
  run_path="$2"
  charter_mode="$3"
  charter_value="$4"
  token_mode="${5:-with-token}"
  launcher_path="${6:-${ROOT_DIR}/bin/albion}"
  shift 6 || true

  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"
  record_file="${TMP_DIR}/${name}.record"
  : >"$record_file"

  env_vars=(
    "PATH=${run_path}"
    "TMPDIR=${TMPDIR:-/tmp}"
    "ALBION_STUB_RECORD=${record_file}"
  )

  if [ "$token_mode" = "with-token" ]; then
    env_vars+=("ALBION_ZAI_TOKEN=test-token")
  fi

  if [ -n "${ALBION_MODEL+x}" ]; then
    env_vars+=("ALBION_MODEL=${ALBION_MODEL}")
  fi

  case "$charter_mode" in
    set) env_vars+=("ALBION_CHARTER=${charter_value}") ;;
    unset) ;;
    *)
      assert_fail "unknown charter mode ${charter_mode}"
      return 1
      ;;
  esac

  set +e
  env -i "${env_vars[@]}" bash "$launcher_path" "$@" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  set -e
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  RUN_RECORD="$(cat "$record_file")"
}

write_charter() {
  local path
  local path_dir
  path="${TMP_DIR}/charter.md"
  printf 'temporary Albion charter\n' >"$path"
  path_dir="$(cd -P "$(dirname "$path")" && pwd)"
  printf '%s/%s\n' "$path_dir" "$(basename "$path")"
}

charter_path="$(write_charter)"
missing_charter="${TMP_DIR}/missing-charter.md"

stub_path="$(make_stub_path default)"
run_launcher "default" "$stub_path" set "$charter_path" with-token "${ROOT_DIR}/bin/albion" \
  --model opus "prompt with spaces" "--flag=value"
assert_exit_code 0 "$RUN_CODE" "default mode exits with stub status"
assert_eq "" "$RUN_STDERR" "default mode with charter is stderr-quiet"
assert_contains "$RUN_RECORD" "agent=Albion" "default mode exports Albion agent name"
assert_contains "$RUN_RECORD" "base_url=https://api.z.ai/api/anthropic" "default mode sources Albion env"
assert_contains "$RUN_RECORD" "append_present=1" "default mode appends charter"
assert_contains "$RUN_RECORD" "argc=10" "default mode preserves passthrough count after charter, plugin, and settings args"
assert_contains "$RUN_RECORD" "argv[0]=--append-system-prompt" "charter flag is first claude arg"
assert_contains "$RUN_RECORD" "argv[1]=temporary Albion charter" "charter content is passed as prompt"
assert_contains "$RUN_RECORD" "argv[2]=--plugin-dir" "default mode passes plugin-dir flag"
assert_contains "$RUN_RECORD" "argv[3]=${PLUGIN_DIR}" "default mode passes resolved plugin dir"
assert_contains "$RUN_RECORD" "argv[4]=--settings" "default mode passes settings flag"
assert_contains "$RUN_RECORD" "argv[5]=${SETTINGS_PATH}" "default mode passes albion settings path"
assert_contains "$RUN_RECORD" "argv[6]=--model" "passthrough arg 1 reaches claude"
assert_contains "$RUN_RECORD" "argv[7]=opus" "passthrough arg 2 reaches claude"
assert_contains "$RUN_RECORD" "argv[8]=prompt with spaces" "passthrough with spaces reaches claude"
assert_contains "$RUN_RECORD" "argv[9]=--flag=value" "passthrough flag reaches claude"
assert_not_contains "$RUN_STDERR" "test-token" "default mode does not print token"
assert_not_contains "$RUN_STDOUT" "test-token" "default mode stdout does not print token"

stub_path="$(make_stub_path injected-model)"
run_launcher "injected-model" "$stub_path" set "$charter_path" with-token "${ROOT_DIR}/bin/albion" \
  "prompt with default model"
assert_exit_code 0 "$RUN_CODE" "default mode injects default model"
assert_contains "$RUN_RECORD" "argc=9" "default model injection preserves passthrough count after charter, plugin, settings, and model args"
assert_contains "$RUN_RECORD" "argv[0]=--append-system-prompt" "default model keeps charter flag first"
assert_contains "$RUN_RECORD" "argv[1]=temporary Albion charter" "default model keeps charter content second"
assert_contains "$RUN_RECORD" "argv[2]=--plugin-dir" "default model keeps plugin flag after charter"
assert_contains "$RUN_RECORD" "argv[3]=${PLUGIN_DIR}" "default model keeps plugin dir after charter"
assert_contains "$RUN_RECORD" "argv[4]=--settings" "default model keeps settings flag after plugin"
assert_contains "$RUN_RECORD" "argv[5]=${SETTINGS_PATH}" "default model keeps settings path after plugin"
assert_contains "$RUN_RECORD" "argv[6]=--model" "default mode injects model flag"
assert_contains "$RUN_RECORD" "argv[7]=glm-5.2[1m]" "default mode injects GLM model"
assert_contains "$RUN_RECORD" "argv[8]=prompt with default model" "default model preserves passthrough"

stub_path="$(make_stub_path albion-model)"
# Charter must be pinned to a nonexistent path: with ALBION_CHARTER unset the
# launcher falls back to the repo's real charter/ALBION.md, coupling this
# model-injection case to repo contents.
ALBION_MODEL=bar run_launcher "albion-model" "$stub_path" set "$missing_charter" with-token "${ROOT_DIR}/bin/albion" \
  "prompt with env model"
assert_exit_code 0 "$RUN_CODE" "ALBION_MODEL changes injected model"
assert_contains "$RUN_RECORD" "argc=7" "ALBION_MODEL run has plugin args, settings args, model args, and passthrough"
assert_contains "$RUN_RECORD" "argv[0]=--plugin-dir" "ALBION_MODEL run still passes plugin-dir flag"
assert_contains "$RUN_RECORD" "argv[1]=${PLUGIN_DIR}" "ALBION_MODEL run passes resolved plugin dir"
assert_contains "$RUN_RECORD" "argv[2]=--settings" "ALBION_MODEL run passes settings flag"
assert_contains "$RUN_RECORD" "argv[3]=${SETTINGS_PATH}" "ALBION_MODEL run passes settings path"
assert_contains "$RUN_RECORD" "argv[4]=--model" "ALBION_MODEL injects model flag"
assert_contains "$RUN_RECORD" "argv[5]=bar" "ALBION_MODEL value reaches claude"
assert_contains "$RUN_RECORD" "argv[6]=prompt with env model" "ALBION_MODEL preserves passthrough"

link_dir="${TMP_DIR}/linked-bin"
mkdir -p "$link_dir"
ln -s "${ROOT_DIR}/bin/albion" "${link_dir}/albion"
stub_path="$(make_stub_path symlink)"
run_launcher "symlink" "$stub_path" set "$charter_path" with-token "${link_dir}/albion" \
  "from symlink"
assert_exit_code 0 "$RUN_CODE" "launcher resolves repo root through a symlink"
assert_contains "$RUN_RECORD" "agent=Albion" "symlinked launcher still sources env"
assert_contains "$RUN_RECORD" "append_present=1" "symlinked launcher still resolves charter"
assert_contains "$RUN_RECORD" "argv[2]=--plugin-dir" "symlinked launcher still passes plugin-dir flag"
assert_contains "$RUN_RECORD" "argv[3]=${PLUGIN_DIR}" "symlinked launcher resolves plugin dir through symlink"

stub_path="$(make_stub_path missing-charter)"
run_launcher "missing-charter" "$stub_path" set "$missing_charter" with-token "${ROOT_DIR}/bin/albion" \
  "still runs"
assert_exit_code 0 "$RUN_CODE" "default mode without charter still runs"
assert_contains "$RUN_STDERR" "running without the orchestration charter" "missing charter warns"
assert_contains "$RUN_RECORD" "agent=Albion" "missing charter keeps default agent"
assert_contains "$RUN_RECORD" "append_present=0" "missing charter omits append"
assert_contains "$RUN_RECORD" "argv[0]=--plugin-dir" "missing charter still passes plugin-dir flag"
assert_contains "$RUN_RECORD" "argv[1]=${PLUGIN_DIR}" "missing charter still passes resolved plugin dir"
assert_contains "$RUN_RECORD" "argv[2]=--settings" "missing charter still passes settings flag"
assert_contains "$RUN_RECORD" "argv[3]=${SETTINGS_PATH}" "missing charter still passes settings path"
assert_contains "$RUN_RECORD" "argv[4]=--model" "missing charter injects model flag"
assert_contains "$RUN_RECORD" "argv[5]=glm-5.2[1m]" "missing charter injects default model"
assert_contains "$RUN_RECORD" "argv[6]=still runs" "missing charter preserves passthrough"

missing_plugin_repo="${TMP_DIR}/missing-plugin-repo"
mkdir -p "${missing_plugin_repo}/bin" "${missing_plugin_repo}/env"
cp "${ROOT_DIR}/bin/albion" "${missing_plugin_repo}/bin/albion"
cp "${ROOT_DIR}/env/albion-env.sh" "${missing_plugin_repo}/env/albion-env.sh"
stub_path="$(make_stub_path missing-plugin)"
run_launcher "missing-plugin" "$stub_path" set "$charter_path" with-token "${missing_plugin_repo}/bin/albion" \
  "still runs without plugin"
assert_exit_code 0 "$RUN_CODE" "default mode without plugin dir still runs"
assert_contains "$RUN_STDERR" "running without the Albion plugin directory" "missing plugin dir warns"
assert_contains "$RUN_RECORD" "agent=Albion" "missing plugin keeps default agent"
assert_contains "$RUN_RECORD" "append_present=1" "missing plugin still appends charter"
assert_not_contains "$RUN_RECORD" "--plugin-dir" "missing plugin omits plugin-dir flag"
assert_contains "$RUN_RECORD" "argv[2]=--model" "missing plugin injects model after charter"
assert_contains "$RUN_RECORD" "argv[3]=glm-5.2[1m]" "missing plugin injects default model"
assert_contains "$RUN_RECORD" "argv[4]=still runs without plugin" "missing plugin preserves passthrough"

stub_path="$(make_stub_path vanilla)"
run_launcher "vanilla" "$stub_path" set "$charter_path" with-token "${ROOT_DIR}/bin/albion" \
  --vanilla "control arm"
assert_exit_code 0 "$RUN_CODE" "vanilla mode runs"
assert_eq "" "$RUN_STDERR" "vanilla mode ignores charter without warning"
assert_contains "$RUN_RECORD" "agent=Albion-vanilla" "vanilla exports control-arm agent name"
assert_contains "$RUN_RECORD" "append_present=0" "vanilla omits charter append"
assert_contains "$RUN_RECORD" "argv[0]=--model" "vanilla injects model flag"
assert_contains "$RUN_RECORD" "argv[1]=glm-5.2[1m]" "vanilla injects default model"
assert_contains "$RUN_RECORD" "argv[2]=control arm" "vanilla preserves passthrough"
assert_not_contains "$RUN_RECORD" "--plugin-dir" "vanilla does not pass plugin-dir"

stub_path="$(make_stub_path dry-run-default)"
run_launcher "dry-run-default" "$stub_path" set "$charter_path" with-token "${ROOT_DIR}/bin/albion" \
  --dry-run "preview"
assert_exit_code 0 "$RUN_CODE" "default dry-run exits zero"
assert_eq "" "$RUN_RECORD" "default dry-run does not invoke claude"
assert_contains "$RUN_STDOUT" "mode=default" "default dry-run prints mode"
assert_contains "$RUN_STDOUT" "auth_lane=plan" "default dry-run prints auth lane"
assert_contains "$RUN_STDOUT" "anthropic_auth_token=***set***" "default dry-run masks set token"
assert_contains "$RUN_STDOUT" "opus_model=glm-5.2[1m]" "default dry-run prints opus slot"
assert_contains "$RUN_STDOUT" "sonnet_model=glm-5.2[1m]" "default dry-run prints sonnet slot"
assert_contains "$RUN_STDOUT" "haiku_model=glm-5-turbo" "default dry-run prints haiku slot"
assert_contains "$RUN_STDOUT" "model=glm-5.2[1m]" "default dry-run prints resolved model"
assert_contains "$RUN_STDOUT" "charter=${charter_path}" "default dry-run prints charter path"
assert_contains "$RUN_STDOUT" "--append-system-prompt" "default dry-run prints final argv"
assert_contains "$RUN_STDOUT" "--plugin-dir ${PLUGIN_DIR}" "default dry-run prints plugin-dir argv"
assert_contains "$RUN_STDOUT" "--model glm-5.2\\[1m\\]" "default dry-run prints injected model argv"
assert_not_contains "$RUN_STDOUT" "test-token" "default dry-run never prints token value"
assert_not_contains "$RUN_STDERR" "test-token" "default dry-run stderr never prints token value"

stub_path="$(make_stub_path dry-run-vanilla)"
run_launcher "dry-run-vanilla" "$stub_path" set "$charter_path" with-token "${ROOT_DIR}/bin/albion" \
  --vanilla --dry-run "preview"
assert_exit_code 0 "$RUN_CODE" "vanilla dry-run exits zero"
assert_eq "" "$RUN_RECORD" "vanilla dry-run does not invoke claude"
assert_contains "$RUN_STDOUT" "mode=vanilla" "vanilla dry-run prints mode"
assert_contains "$RUN_STDOUT" "model=glm-5.2[1m]" "vanilla dry-run prints resolved model"
assert_contains "$RUN_STDOUT" "charter=(none)" "vanilla dry-run prints no charter"
assert_not_contains "$RUN_STDOUT" "--append-system-prompt" "vanilla dry-run omits charter append"
assert_not_contains "$RUN_STDOUT" "--plugin-dir" "vanilla dry-run omits plugin-dir"
assert_contains "$RUN_STDOUT" "--model glm-5.2\\[1m\\]" "vanilla dry-run prints injected model argv"
assert_not_contains "$RUN_STDOUT" "test-token" "vanilla dry-run never prints token value"

run_launcher "missing-token" "$BASE_PATH" set "$charter_path" without-token "${ROOT_DIR}/bin/albion"
assert_exit_code 1 "$RUN_CODE" "env source failure exits 1"
assert_contains "$RUN_STDERR" "ALBION_ZAI_PLAN_TOKEN" "env failure relays env stderr"
assert_not_contains "$RUN_STDERR" "test-token" "env failure does not invent token output"

run_launcher "missing-claude" "$BASE_PATH" set "$charter_path" with-token "${ROOT_DIR}/bin/albion"
assert_exit_code 2 "$RUN_CODE" "missing claude exits 2"
assert_contains "$RUN_STDERR" "claude binary not found on PATH" "missing claude names failure"
assert_contains "$RUN_STDERR" "install Claude Code" "missing claude names remedy"

stub_path="$(make_stub_path unknown)"
run_launcher "unknown" "$stub_path" set "$charter_path" with-token "${ROOT_DIR}/bin/albion" \
  --albion-x
assert_exit_code 4 "$RUN_CODE" "unknown Albion flag exits 4"
assert_contains "$RUN_STDERR" "unknown Albion flag: --albion-x" "unknown flag names the bad flag"
assert_eq "" "$RUN_RECORD" "unknown flag does not invoke claude"

stub_path="$(make_stub_path doctor)"
run_launcher "doctor" "$stub_path" set "$charter_path" with-token "${ROOT_DIR}/bin/albion" \
  --doctor --verbose
assert_exit_code 3 "$RUN_CODE" "absent doctor exits 3"
assert_contains "$RUN_STDERR" "doctor not installed yet" "doctor absence message is clear"
assert_eq "" "$RUN_RECORD" "absent doctor does not invoke claude"
