#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/albion-effort.XXXXXX")"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

assert_not_contains() {
  case "$1" in
    *"$2"*) assert_fail "${3:-should not contain}: '${1}' contains '${2}'"; return 1 ;;
  esac
}

# minimal claude stub so version/binary checks are quiet and deterministic
STUB="${TMP_DIR}/bin"
mkdir -p "$STUB"
cat >"${STUB}/claude" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && { printf 'Claude Code 2.1.200\n'; exit 0; }
printf 'stub\n'
EOF
chmod +x "${STUB}/claude"

run_doctor_with_settings() {
  local settings_path="$1"
  env -i \
    TMPDIR="${TMPDIR:-/tmp}" \
    PATH="${STUB}:/usr/bin:/bin" \
    ALBION_ZAI_TOKEN=test-token \
    ALBION_SETTINGS_PATH="$settings_path" \
    "${ROOT_DIR}/bin/albion-doctor" --offline 2>/dev/null || true
}

# xhigh -> PASS
printf '{"effortLevel":"xhigh"}\n' >"${TMP_DIR}/xhigh.json"
out="$(run_doctor_with_settings "${TMP_DIR}/xhigh.json")"
assert_contains "$out" "PASS effort: effortLevel=xhigh" "xhigh effort passes"

# high -> WARN naming the shortfall
printf '{"effortLevel":"high"}\n' >"${TMP_DIR}/high.json"
out="$(run_doctor_with_settings "${TMP_DIR}/high.json")"
assert_contains "$out" "WARN effort: effortLevel=high" "high effort warns"
assert_contains "$out" "expects xhigh" "warning names the expected xhigh tier"

# unset key -> WARN
printf '{"tui":"fullscreen"}\n' >"${TMP_DIR}/unset.json"
out="$(run_doctor_with_settings "${TMP_DIR}/unset.json")"
assert_contains "$out" "WARN effort: effortLevel unset" "missing effortLevel warns"

# unreadable settings -> SKIP (the albion config is missing)
out="$(run_doctor_with_settings "${TMP_DIR}/does-not-exist.json")"
assert_contains "$out" "SKIP effort:" "unresolvable settings skips the effort check"

# the summary tally must still equal the count of PASS lines (no counter drift)
out="$(run_doctor_with_settings "${TMP_DIR}/xhigh.json")"
pass_lines="$(printf '%s\n' "$out" | grep -c '^PASS ')"
summary_passes="$(printf '%s\n' "$out" | sed -n 's/^\([0-9][0-9]*\) pass.*/\1/p')"
assert_eq "$pass_lines" "$summary_passes" "doctor pass tally matches PASS lines with effort check active"

# --- deny floor is wired into the injected settings layer -------------------
# The security model names permissions-deny as the hard floor; the launcher
# delivers config/albion-settings.json via --settings, so the deny rules must
# live there — and must stay byte-identical to the stock-claude fragment in
# plugin/settings/permissions-deny.json (the manual-merge copy).

if ! python3 - "${ROOT_DIR}/config/albion-settings.json" <<'PY'
import json, sys
settings = json.load(open(sys.argv[1]))
deny = settings.get("permissions", {}).get("deny")
assert isinstance(deny, list) and deny, "injected settings must carry permissions.deny"
assert "Bash(rm -rf:*)" in deny, "deny floor must include the rm -rf rule"
assert "Read(**/secrets/**)" in deny, "deny floor must include the secrets read rule"
PY
then
  assert_fail "injected settings layer is missing the deny floor"
fi
printf 'ok - injected settings layer carries the deny floor\n'

if ! python3 - "${ROOT_DIR}/config/albion-settings.json" "${ROOT_DIR}/plugin/settings/permissions-deny.json" <<'PY'
import json, sys
wired = json.load(open(sys.argv[1]))["permissions"]["deny"]
fragment = json.load(open(sys.argv[2]))["permissions"]["deny"]
assert wired == fragment, (
    "deny lists drifted between config/albion-settings.json and "
    "plugin/settings/permissions-deny.json — update both together"
)
PY
then
  assert_fail "deny floor drift between wired settings and the stock fragment"
fi
printf 'ok - wired deny floor matches plugin/settings/permissions-deny.json\n'
