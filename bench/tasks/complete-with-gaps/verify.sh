#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import hashlib
import sys
from pathlib import Path

for line in Path(".bench/test-hashes.sha256").read_text(encoding="utf-8").splitlines():
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

python3 - <<'PY'
import json
import subprocess
import sys
from pathlib import Path

output = subprocess.check_output(
    [
        sys.executable,
        "-m",
        "reports.cli",
        "--from",
        "2026-07-01",
        "--to",
        "2026-07-02",
        "--json",
    ],
    text=True,
)
rows = json.loads(output)
assert rows == [
    {"date": "2026-07-01", "name": "alpha", "amount": 10},
    {"date": "2026-07-02", "name": "bravo", "amount": 20},
], rows

usage = Path("docs/usage.md").read_text(encoding="utf-8").lower()
assert "--json" in usage or "json" in usage, usage
PY
