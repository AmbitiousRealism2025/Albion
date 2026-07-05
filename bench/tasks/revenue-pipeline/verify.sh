#!/usr/bin/env bash
set -euo pipefail

# Deterministic: never trust stale bytecode from an earlier (buggy) run.
find . -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true

python3 - <<'PY'
import hashlib, sys
from pathlib import Path
for line in Path(".bench/test-hashes.sha256").read_text(encoding="utf-8").splitlines():
    expected, raw = line.split("  ", 1)
    p = Path(raw)
    if not p.is_file():
        print(f"missing protected test file: {p}", file=sys.stderr); raise SystemExit(1)
    if hashlib.sha256(p.read_bytes()).hexdigest() != expected:
        print(f"protected test file changed: {p}", file=sys.stderr); raise SystemExit(1)
PY

python3 -B -m unittest discover -s tests -p 'test_*.py'
