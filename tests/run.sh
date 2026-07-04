#!/usr/bin/env bash
set -euo pipefail

main() {
  local root_dir
  local test_dir
  local test_file
  local test_name
  local pass_count
  local fail_count
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  test_dir="${root_dir}/tests"
  pass_count=0
  fail_count=0

  shopt -s nullglob
  local test_files=("${test_dir}"/test_*.sh)
  shopt -u nullglob

  if [ "${#test_files[@]}" -eq 0 ]; then
    printf 'No tests found in %s\n' "$test_dir" >&2
    return 1
  fi

  for test_file in "${test_files[@]}"; do
    test_name="$(basename "$test_file")"
    if bash "$test_file"; then
      printf 'PASS %s\n' "$test_name"
      pass_count=$((pass_count + 1))
    else
      printf 'FAIL %s\n' "$test_name"
      fail_count=$((fail_count + 1))
    fi
  done

  printf 'Summary: %d passed, %d failed\n' "$pass_count" "$fail_count"

  if [ "$fail_count" -ne 0 ]; then
    return 1
  fi
}

main "$@"
