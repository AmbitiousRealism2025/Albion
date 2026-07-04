#!/usr/bin/env bash
set -euo pipefail

mkdir -p textnorm tests .bench

cat > textnorm/__init__.py <<'PY'
PY

cat > textnorm/normalize.py <<'PY'
def normalize(text):
    """Collapse every run of whitespace to a single space and strip the ends.

    "a\t b\n\nc  d " -> "a b c d"
    """
    # Bug: only collapses runs of exactly two spaces, leaving tabs, newlines,
    # and longer runs intact.
    collapsed = text.replace("  ", " ")
    return collapsed.strip()


def word_count(text):
    return len(normalize(text).split(" ")) if normalize(text) else 0
PY

cat > tests/test_normalize.py <<'PY'
import unittest

from textnorm.normalize import normalize, word_count


class NormalizeTests(unittest.TestCase):
    def test_collapses_mixed_whitespace(self):
        self.assertEqual(normalize("a\t b\n\nc  d "), "a b c d")

    def test_collapses_long_space_runs(self):
        self.assertEqual(normalize("x     y"), "x y")

    def test_strips_and_counts(self):
        self.assertEqual(word_count("  one\ttwo   three "), 3)

    def test_empty_is_zero_words(self):
        self.assertEqual(word_count("   \t\n "), 0)


if __name__ == "__main__":
    unittest.main()
PY

python3 - <<'PY'
import hashlib
from pathlib import Path

root = Path("tests")
lines = []
for path in sorted(root.glob("test_*.py")):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    lines.append(f"{digest}  {path.as_posix()}\n")
Path(".bench/test-hashes.sha256").write_text("".join(lines), encoding="utf-8")
PY
