#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/albion-package.XXXXXX")"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

OUT="${TMP_DIR}/dist"
"${ROOT_DIR}/bin/albion-package" --out "$OUT" >/dev/null 2>&1 || assert_fail "albion-package exited non-zero"
OUT="$(cd "$OUT" && pwd -P)"

# The result is a valid plugin AND carries the launcher's runtime dependencies.
for p in .claude-plugin/plugin.json hooks/hooks.json scripts/stop-gate.sh skills agents \
         bin/albion bin/albion-doctor env/albion-env.sh charter/ALBION.md \
         config/albion-settings.json state/state-lib.sh; do
  [ -e "${OUT}/${p}" ] || assert_fail "packaged plugin missing ${p}"
done

# The packaged launcher resolves the plugin, settings, and charter from INSIDE
# the package (default mode), proving self-containment.
dry="$(ALBION_ZAI_TOKEN=probe "${OUT}/bin/albion" --dry-run 2>/dev/null)"
assert_contains "$dry" "--plugin-dir ${OUT}" "packaged launcher self-resolves plugin-dir to the package"
assert_contains "$dry" "--settings ${OUT}/config/albion-settings.json" "packaged launcher self-resolves the settings config"
assert_contains "$dry" "ALBION.md" "packaged launcher appends the bundled charter"

# The packaged doctor works: hooks register from the package; the manifest check
# skips cleanly (a packaged plugin ships no manifest source).
doctor="$(ALBION_ZAI_TOKEN=probe "${OUT}/bin/albion-doctor" --offline 2>/dev/null || true)"
assert_contains "$doctor" "PASS hook-suite:" "packaged doctor verifies hooks from the package"
assert_contains "$doctor" "SKIP manifest:" "packaged doctor skips the manifest check with no source"

# The dev suite's launcher/doctor still resolve the classic layout (plugin subdir).
[ -f "${ROOT_DIR}/plugin/.claude-plugin/plugin.json" ] || assert_fail "dev layout precondition"
