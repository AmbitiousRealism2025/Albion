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
from store.catalog import Catalog

catalog = Catalog()
catalog.load({"a": "red apple", "b": "blue berry", "c": "green melon"})
catalog.update("a", "green pear")
catalog.delete("b")
assert catalog.search("red") == [], catalog.search("red")
assert catalog.search("green") == ["a", "c"], catalog.search("green")
assert catalog.search("blue") == [], catalog.search("blue")

catalog.update("d", "red grape")
catalog.update("c", "blue melon")
catalog.delete("a")
assert catalog.search("green") == [], catalog.search("green")
assert catalog.search("red") == ["d"], catalog.search("red")
assert catalog.search("blue") == ["c"], catalog.search("blue")
PY
