#!/usr/bin/env bash

assert_fail() {
  local message
  message="$1"

  printf 'ASSERT FAIL: %s\n' "$message" >&2
  return 1
}

assert_eq() {
  local expected
  local actual
  local message
  expected="$1"
  actual="$2"
  message="${3:-values should be equal}"

  if [ "$expected" != "$actual" ]; then
    assert_fail "${message}: expected '${expected}', got '${actual}'"
    return 1
  fi
}

assert_contains() {
  local haystack
  local needle
  local message
  haystack="$1"
  needle="$2"
  message="${3:-string should contain substring}"

  case "$haystack" in
    *"$needle"*) ;;
    *)
      assert_fail "${message}: expected '${haystack}' to contain '${needle}'"
      return 1
      ;;
  esac
}

assert_file_exists() {
  local path
  local message
  path="$1"
  message="${2:-file should exist}"

  if [ ! -f "$path" ]; then
    assert_fail "${message}: '${path}' does not exist"
    return 1
  fi
}

assert_exit_code() {
  local expected
  local actual
  local message
  expected="$1"
  actual="$2"
  message="${3:-exit code should match}"

  if [ "$expected" -ne "$actual" ]; then
    assert_fail "${message}: expected ${expected}, got ${actual}"
    return 1
  fi
}
