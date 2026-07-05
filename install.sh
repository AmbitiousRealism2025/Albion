#!/usr/bin/env bash
set -euo pipefail

MIN_CLAUDE_VERSION="2.1.163"
PREFERRED_CLAUDE_VERSION="2.1.195"
TOOL_NAMES="albion albion-doctor albion-vision albion-compile"

print_usage() {
  cat <<'USAGE'
Usage: ./install.sh [--prefix DIR] [--no-doctor] [--help]

Installs Albion command symlinks into a PATH directory, checks local
prerequisites, and optionally runs albion-doctor --offline.
USAGE
}

resolve_script_dir() {
  local source_path
  local source_dir

  source_path="${BASH_SOURCE[0]}"
  while [ -h "$source_path" ]; do
    source_dir="$(cd -P "$(dirname "$source_path")" && pwd)"
    source_path="$(readlink "$source_path")"
    case "$source_path" in
      /*) ;;
      *) source_path="${source_dir}/${source_path}" ;;
    esac
  done

  cd -P "$(dirname "$source_path")" && pwd
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf 'WARN: %s\n' "$1" >&2
}

parse_args() {
  prefix_dir=""
  run_doctor=1

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --prefix)
        if [ "$#" -lt 2 ]; then
          fail "--prefix requires a directory argument"
        fi
        prefix_dir="$2"
        shift
        ;;
      --prefix=*)
        prefix_dir="${1#--prefix=}"
        ;;
      --no-doctor)
        run_doctor=0
        ;;
      --help)
        print_usage
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
    shift
  done

  if [ -z "$prefix_dir" ]; then
    if [ -z "${HOME:-}" ]; then
      fail "HOME is unset; pass --prefix DIR"
    fi
    prefix_dir="${HOME}/.local/bin"
  fi
}

check_required_tool() {
  local tool_name

  tool_name="$1"
  if command -v "$tool_name" >/dev/null 2>&1; then
    return 0
  fi

  case "$tool_name" in
    bash) fail "missing prerequisite: bash not found on PATH; install bash or add it to PATH." ;;
    python3) fail "missing prerequisite: python3 not found on PATH; install Python 3 and add python3 to PATH." ;;
    curl) fail "missing prerequisite: curl not found on PATH; install curl or add it to PATH." ;;
    git) fail "missing prerequisite: git not found on PATH; install git or add it to PATH." ;;
    *) fail "missing prerequisite: ${tool_name} not found on PATH." ;;
  esac
}

version_at_least() {
  local major
  local minor
  local patch
  local target_major
  local target_minor
  local target_patch

  major="$1"
  minor="$2"
  patch="$3"
  target_major="$4"
  target_minor="$5"
  target_patch="$6"

  if [ "$major" -gt "$target_major" ]; then
    return 0
  fi
  if [ "$major" -lt "$target_major" ]; then
    return 1
  fi
  if [ "$minor" -gt "$target_minor" ]; then
    return 0
  fi
  if [ "$minor" -lt "$target_minor" ]; then
    return 1
  fi
  [ "$patch" -ge "$target_patch" ]
}

parse_version_triplet() {
  python3 - "$1" <<'PY'
import re
import sys

match = re.search(r"([0-9]+)\.([0-9]+)\.([0-9]+)", sys.argv[1])
if not match:
    sys.exit(1)
print(" ".join(match.groups()))
PY
}

check_claude() {
  local version_output
  local parsed_triplet
  local major
  local minor
  local patch
  local parsed_version

  if ! command -v claude >/dev/null 2>&1; then
    warn "claude not found on PATH; Albion can install, but bin/albion cannot run until Claude Code is installed."
    return 0
  fi

  if ! version_output="$(claude --version 2>&1)"; then
    warn "could not run claude --version: ${version_output}"
    return 0
  fi

  if ! parsed_triplet="$(parse_version_triplet "$version_output")"; then
    warn "could not parse claude --version output: ${version_output}"
    return 0
  fi

  read -r major minor patch <<EOF
$parsed_triplet
EOF
  parsed_version="${major}.${minor}.${patch}"

  if ! version_at_least "$major" "$minor" "$patch" 2 1 163; then
    fail "Claude Code ${parsed_version} is below ${MIN_CLAUDE_VERSION}; upgrade Claude Code and rerun ./install.sh."
  fi

  if ! version_at_least "$major" "$minor" "$patch" 2 1 195; then
    warn "Claude Code ${parsed_version} meets ${MIN_CLAUDE_VERSION}, but ${PREFERRED_CLAUDE_VERSION} or newer is preferred."
    return 0
  fi

  printf 'Claude Code %s OK\n' "$parsed_version"
}

check_prerequisites() {
  check_required_tool bash
  check_required_tool python3
  check_required_tool curl
  check_required_tool git
  check_claude
}

canonicalize_dir() {
  local dir_path

  dir_path="$1"
  mkdir -p "$dir_path"
  cd "$dir_path" && pwd -P
}

resolve_path() {
  python3 - "$1" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
}

path_is_inside() {
  python3 - "$1" "$2" <<'PY'
import os
import sys

candidate = os.path.realpath(sys.argv[1])
root = os.path.realpath(sys.argv[2])
try:
    inside = os.path.commonpath([candidate, root]) == root
except ValueError:
    inside = False
sys.exit(0 if inside else 1)
PY
}

install_tool() {
  local tool_name
  local source_path
  local dest_path
  local existing_target
  local resolved_target

  tool_name="$1"
  source_path="${repo_root}/bin/${tool_name}"
  dest_path="${prefix_dir}/${tool_name}"

  if [ ! -x "$source_path" ]; then
    printf 'ERROR: source tool is missing or not executable: %s\n' "$source_path" >&2
    return 1
  fi

  if [ -e "$dest_path" ] || [ -L "$dest_path" ]; then
    if [ ! -L "$dest_path" ]; then
      printf 'SKIP %s: found non-symlink at %s\n' "$tool_name" "$dest_path" >&2
      return 1
    fi

    existing_target="$(readlink "$dest_path")"
    resolved_target="$(resolve_path "$dest_path")"
    if ! path_is_inside "$resolved_target" "$repo_root"; then
      printf 'SKIP %s: symlink at %s points outside this repo: %s -> %s\n' \
        "$tool_name" "$dest_path" "$existing_target" "$resolved_target" >&2
      return 1
    fi

    rm "$dest_path"
  fi

  ln -s "$source_path" "$dest_path"
  printf 'Installed %s -> %s\n' "$dest_path" "$source_path"
}

verify_albion_symlink() {
  local resolved_target

  resolved_target="$(resolve_path "${prefix_dir}/albion")"
  if [ "$resolved_target" != "${repo_root}/bin/albion" ]; then
    printf 'ERROR: %s resolves to %s; expected %s\n' \
      "${prefix_dir}/albion" "$resolved_target" "${repo_root}/bin/albion" >&2
    return 1
  fi

  if ! path_is_inside "$resolved_target" "$repo_root"; then
    printf 'ERROR: %s does not resolve inside %s\n' "${prefix_dir}/albion" "$repo_root" >&2
    return 1
  fi
}

print_path_guidance() {
  case ":${PATH:-}:" in
    *":${prefix_dir}:"*) ;;
    *)
      printf 'Add Albion to your PATH by adding this line to your shell profile:\n'
      printf "  export PATH=%q:\"\$PATH\"\n" "$prefix_dir"
      ;;
  esac
}

print_token_guidance() {
  printf 'Before first run, set a Z.ai credential without sharing it with the installer:\n'
  printf '  export ALBION_ZAI_TOKEN="<your plan token>"\n'
  printf '  # or: export ALBION_AUTH_LANE=api ALBION_ZAI_API_KEY="<your api key>"\n'
}

run_doctor_offline() {
  local doctor_output
  local doctor_code
  local doctor_summary

  set +e
  doctor_output="$("${repo_root}/bin/albion-doctor" --offline 2>&1)"
  doctor_code=$?
  set -e

  doctor_summary="${doctor_output##*$'\n'}"
  printf 'albion-doctor --offline: %s\n' "$doctor_summary"
  return "$doctor_code"
}

main() {
  local install_errors
  local tool_name

  repo_root="$(resolve_script_dir)"
  parse_args "$@"
  check_prerequisites
  prefix_dir="$(canonicalize_dir "$prefix_dir")"
  install_errors=0

  for tool_name in $TOOL_NAMES; do
    if ! install_tool "$tool_name"; then
      install_errors=1
    fi
  done

  if ! verify_albion_symlink; then
    install_errors=1
  fi

  print_path_guidance
  print_token_guidance

  if [ "$install_errors" -ne 0 ]; then
    return 1
  fi

  if [ "$run_doctor" -eq 1 ]; then
    run_doctor_offline
    return $?
  fi

  return 0
}

repo_root=""
prefix_dir=""
run_doctor=1

main "$@"
