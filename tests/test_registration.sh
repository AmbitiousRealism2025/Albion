#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

TOOL="${ROOT_DIR}/tests/tools/verify-registration.sh"

assert_file_exists "$TOOL" "registration verifier exists"
[ -x "$TOOL" ] || assert_fail "registration verifier is executable"
bash -n "$TOOL" || assert_fail "registration verifier parses"

# With no token, it must SKIP cleanly (exit 3) and never attempt a launch.
set +e
out="$(env -i TMPDIR="${TMPDIR:-/tmp}" PATH="/usr/bin:/bin" bash "$TOOL" 2>&1)"
code=$?
set -e
assert_eq "3" "$code" "no-token run exits 3 (skip)"
assert_contains "$out" "SKIP" "no-token run reports SKIP"
assert_contains "$out" "ALBION_ZAI_TOKEN" "skip message names the token variable"
