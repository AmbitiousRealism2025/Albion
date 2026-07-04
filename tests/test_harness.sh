#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-harness.$$"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$TMP_DIR"
sample_file="${TMP_DIR}/sample.txt"
printf 'albion harness\n' > "$sample_file"

assert_eq "alpha" "alpha" "assert_eq accepts equal values"
assert_contains "albion harness" "harness" "assert_contains finds substrings"
assert_file_exists "$sample_file" "assert_file_exists sees created files"

set +e
bash -c 'exit 7'
actual_code=$?
set -e
assert_exit_code 7 "$actual_code" "assert_exit_code checks captured statuses"

set +e
failure_output="$(assert_eq "expected" "actual" "caught assert_eq failure" 2>&1)"
failure_code=$?
set -e

assert_exit_code 1 "$failure_code" "intentional assertion failure is catchable"
assert_contains "$failure_output" "caught assert_eq failure" "failure output includes caller message"
