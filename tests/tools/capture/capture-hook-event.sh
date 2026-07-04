#!/usr/bin/env bash
set -euo pipefail

fixture_dir() {
  if [ "${ALBION_HOOK_FIXTURE_DIR:-}" != "" ]; then
    printf '%s\n' "$ALBION_HOOK_FIXTURE_DIR"
    return 0
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "${script_dir}/../../fixtures/hooks"
}

capture_payload() {
  local event_name
  local fixtures_dir
  local payload_file
  event_name="${1:-unknown}"
  fixtures_dir="$(fixture_dir)"

  mkdir -p "$fixtures_dir" || return 0
  payload_file="$(mktemp "${TMPDIR:-/tmp}/albion-hook-payload.XXXXXX")" || return 0
  cat > "$payload_file" || true

  python3 - "$payload_file" "${fixtures_dir}/${event_name}.jsonl" "${fixtures_dir}/${event_name}.malformed.log" <<'PY'
import json
import sys

payload_path, output_path, malformed_path = sys.argv[1:4]

with open(payload_path, "r", encoding="utf-8", errors="replace") as handle:
    raw_payload = handle.read()

try:
    parsed_payload = json.loads(raw_payload)
except Exception:
    with open(malformed_path, "a", encoding="utf-8") as handle:
        handle.write(raw_payload)
        if not raw_payload.endswith("\n"):
            handle.write("\n")
else:
    compact_payload = json.dumps(parsed_payload, separators=(",", ":"))
    with open(output_path, "a", encoding="utf-8") as handle:
        handle.write(compact_payload)
        handle.write("\n")
PY

  rm -f "$payload_file" || true
}

main() {
  capture_payload "$@"
}

main "$@" >/dev/null 2>/dev/null || true
exit 0
