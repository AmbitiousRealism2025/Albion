#!/usr/bin/env bash
# Verify that Claude Code actually LOADS Albion's plugin hooks in a real session.
#
# This is distinct from `albion-doctor`'s hook-suite check, which invokes the
# hook scripts directly (proving they WORK). This tool proves REGISTRATION: it
# launches a minimal live Albion session and confirms the plugin's Stop gate
# fired by writing a completion manifest. Hooks declared in a form Claude Code
# silently ignores (see build log 012) would leave no manifest and FAIL here.
#
# Requires a Z.ai token (ALBION_ZAI_TOKEN or ALBION_ZAI_PLAN_TOKEN) and network;
# it makes one trivial model call. Not run in CI (no token there).
#
# Usage: tests/tools/verify-registration.sh
set -uo pipefail

resolve_repo_root() {
  local src="${BASH_SOURCE[0]}"
  while [ -h "$src" ]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="${dir}/${src}" ;; esac
  done
  cd -P "$(dirname "$src")/../.." && pwd
}

REPO="$(resolve_repo_root)"

if [ -z "${ALBION_ZAI_TOKEN:-}" ] && [ -z "${ALBION_ZAI_PLAN_TOKEN:-}" ] && [ -z "${ALBION_ZAI_API_KEY:-}" ]; then
  printf 'SKIP: no Z.ai token in the environment; set ALBION_ZAI_TOKEN and re-run.\n' >&2
  exit 3
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/albion-registration.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
manifest="${WORK}/completion-manifest.json"

printf 'Launching a minimal live Albion session to test hook registration...\n'
(
  cd "$WORK" || exit 1
  ALBION_MANIFEST_PATH="$manifest" \
  ALBION_STATE_DIR="${WORK}/state" \
    "${REPO}/bin/albion" -p "Reply with exactly: OK" --output-format json \
    >"${WORK}/session.json" 2>"${WORK}/session.err"
)

if [ ! -f "$manifest" ]; then
  printf 'FAIL: no completion manifest written — the Stop hook did not register.\n' >&2
  printf '      This is the inert-hooks failure class (see docs/build/log/012).\n' >&2
  exit 1
fi

if ! python3 - "$manifest" <<'PY'
import json, sys
try:
    m = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as exc:
    print(f"manifest did not parse: {exc}", file=sys.stderr); raise SystemExit(1)
if m.get("schema") != "albion-completion-manifest/v1":
    print(f"unexpected manifest schema: {m.get('schema')!r}", file=sys.stderr); raise SystemExit(1)
PY
then
  exit 1
fi

printf 'PASS: plugin hooks registered — the Stop gate wrote a valid completion manifest.\n'
