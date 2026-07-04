#!/usr/bin/env bash
set -euo pipefail

mkdir -p intervals tests .bench

cat > intervals/__init__.py <<'PY'
PY

cat > intervals/merge.py <<'PY'
def merge(intervals):
    """Merge overlapping and touching inclusive [start, end] intervals.

    [1, 3] and [3, 5] touch at 3 and must merge into [1, 5].
    Input need not be sorted; output is sorted by start.
    """
    if not intervals:
        return []
    ordered = sorted(intervals, key=lambda pair: pair[0])
    merged = [list(ordered[0])]
    for start, end in ordered[1:]:
        last = merged[-1]
        # Bug: strict overlap only; adjacent intervals that touch at a single
        # point (start == last_end) are left unmerged.
        if start < last[1]:
            last[1] = max(last[1], end)
        else:
            merged.append([start, end])
    return [tuple(pair) for pair in merged]
PY

cat > tests/test_merge.py <<'PY'
import unittest

from intervals.merge import merge


class MergeTests(unittest.TestCase):
    def test_overlapping_merge(self):
        self.assertEqual(merge([(1, 4), (2, 5)]), [(1, 5)])

    def test_touching_intervals_merge(self):
        self.assertEqual(merge([(1, 3), (3, 5)]), [(1, 5)])

    def test_disjoint_stay_separate(self):
        self.assertEqual(merge([(1, 2), (4, 6)]), [(1, 2), (4, 6)])

    def test_unsorted_input(self):
        self.assertEqual(merge([(8, 10), (1, 3), (2, 6)]), [(1, 6), (8, 10)])


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
