#!/usr/bin/env bash
set -euo pipefail

mkdir -p store tests .bench

cat > store/__init__.py <<'PY'
PY

cat > store/catalog.py <<'PY'
class Catalog:
    def __init__(self):
        self._records = {}
        self._index = {}

    def load(self, records):
        self._records = dict(records)
        self._index = {}
        for key, value in self._records.items():
            for term in value.lower().split():
                self._index.setdefault(term, set()).add(key)

    def update(self, key, value):
        self._records[key] = value

    def delete(self, key):
        self._records.pop(key, None)

    def search(self, term):
        return sorted(self._index.get(term.lower(), set()))
PY

cat > tests/test_catalog.py <<'PY'
import unittest

from store.catalog import Catalog


class CatalogTests(unittest.TestCase):
    def test_search_finds_loaded_records(self):
        catalog = Catalog()
        catalog.load({"a": "red apple", "b": "blue berry"})
        self.assertEqual(catalog.search("red"), ["a"])
        self.assertEqual(catalog.search("blue"), ["b"])

    def test_search_miss_after_fresh_load_is_empty(self):
        catalog = Catalog()
        catalog.load({"a": "red apple"})
        self.assertEqual(catalog.search("green"), [])


if __name__ == "__main__":
    unittest.main()
PY

python3 - <<'PY'
import hashlib
from pathlib import Path

lines = []
for path in sorted(Path("tests").glob("test_*.py")):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    lines.append(f"{digest}  {path.as_posix()}\n")
Path(".bench/test-hashes.sha256").write_text("".join(lines), encoding="utf-8")
PY
