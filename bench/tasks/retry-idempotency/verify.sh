#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import hashlib
import sys
from pathlib import Path

hash_file = Path(".bench/test-hashes.sha256")
for line in hash_file.read_text(encoding="utf-8").splitlines():
    expected, raw_path = line.split("  ", 1)
    path = Path(raw_path)
    if not path.is_file():
        print(f"missing protected test file: {path}", file=sys.stderr)
        raise SystemExit(1)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        print(f"protected test file changed: {path}", file=sys.stderr)
        raise SystemExit(1)
PY

python3 -m unittest discover -s tests -p 'test_*.py'
