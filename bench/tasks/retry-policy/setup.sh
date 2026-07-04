#!/usr/bin/env bash
set -euo pipefail

mkdir -p retry tests .bench

cat > retry/__init__.py <<'PY'
PY

cat > retry/policy.py <<'PY'
def should_retry(attempt, max_attempts):
    """Whether a further attempt is allowed.

    `attempt` is the number of attempts already made (1 after the first try).
    With max_attempts=3, the allowed pattern is: try, retry, retry -> after the
    3rd attempt no further retry. So should_retry is True for attempt 1 and 2,
    False for attempt 3.
    """
    # Bug: off-by-one — stops one retry early.
    return attempt < max_attempts - 1


def backoff_seconds(attempt, base=1):
    """Exponential backoff for the given attempt number (1-indexed)."""
    return base * (2 ** (attempt - 1))
PY

cat > tests/test_policy.py <<'PY'
import unittest

from retry.policy import should_retry, backoff_seconds


class PolicyTests(unittest.TestCase):
    def test_retries_before_limit(self):
        self.assertTrue(should_retry(1, 3))
        self.assertTrue(should_retry(2, 3))

    def test_no_retry_at_limit(self):
        self.assertFalse(should_retry(3, 3))

    def test_single_attempt_policy(self):
        self.assertFalse(should_retry(1, 1))

    def test_backoff_growth(self):
        self.assertEqual(backoff_seconds(1), 1)
        self.assertEqual(backoff_seconds(3), 4)


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
