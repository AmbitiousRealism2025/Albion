#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/albion-setup.XXXXXX")"
TOOL="${ROOT_DIR}/bin/albion-setup"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

assert_not_contains() {
  case "$1" in *"$2"*) assert_fail "${3:-should not contain}: contains '${2}'"; return 1 ;; esac
}

file_mode() {
  python3 -c 'import os,stat,sys; print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode))[2:])' "$1"
}

# --help
set +e; "$TOOL" --help >/dev/null 2>&1; code=$?; set -e
assert_eq "0" "$code" "--help exits 0"

# plan lane, no vision key
sf="${TMP_DIR}/plan.sh"
printf 'plan\nplan-token-xyz\nn\n' | "$TOOL" --secrets-file "$sf" >/dev/null 2>&1
assert_file_exists "$sf" "plan secrets file written"
assert_eq "600" "$(file_mode "$sf")" "secrets file is mode 600"
assert_contains "$(cat "$sf")" "export ALBION_AUTH_LANE=plan" "records plan lane"
assert_contains "$(cat "$sf")" "ALBION_ZAI_TOKEN=" "records plan token var"
assert_not_contains "$(cat "$sf")" "ALBION_VISION_TOKEN" "no vision var when declined"

# api lane with a separate vision key + vision lane
sf="${TMP_DIR}/api.sh"
printf 'api\nmain-api-key\ny\nvision-key-46v\nplan\n' | "$TOOL" --secrets-file "$sf" >/dev/null 2>&1
assert_contains "$(cat "$sf")" "export ALBION_ZAI_API_KEY=" "api lane records api key var"
assert_contains "$(cat "$sf")" "export ALBION_VISION_TOKEN=" "records separate vision token"
assert_contains "$(cat "$sf")" "export ALBION_VISION_LANE=plan" "records vision lane"

# the written file must source cleanly
sf="${TMP_DIR}/src.sh"
printf 'api\nk1\ny\nk2\napi\n' | "$TOOL" --secrets-file "$sf" >/dev/null 2>&1
# shellcheck disable=SC1090
( set -a; . "$sf"; [ "$ALBION_AUTH_LANE" = "api" ] && [ "$ALBION_VISION_TOKEN" = "k2" ] ) \
  || assert_fail "written secrets file sources with expected values"

# empty token aborts with a non-zero exit and no file
sf="${TMP_DIR}/empty.sh"
set +e; printf 'plan\n\n' | "$TOOL" --secrets-file "$sf" >/dev/null 2>&1; code=$?; set -e
assert_eq "1" "$code" "empty token aborts"
if [ -f "$sf" ]; then assert_fail "no file written on empty token"; fi

# an invalid lane is rejected
set +e; printf 'bogus\n' | "$TOOL" --secrets-file "${TMP_DIR}/bad.sh" >/dev/null 2>&1; code=$?; set -e
assert_eq "1" "$code" "invalid lane rejected"
