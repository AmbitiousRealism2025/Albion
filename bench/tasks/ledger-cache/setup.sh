#!/usr/bin/env bash
set -euo pipefail

mkdir -p ledger tests .bench

cat > ledger/cache.py <<'PY'
class LedgerCache:
    def __init__(self):
        self._entries = []
        self._balance = None

    def add(self, account, amount):
        self._entries.append((account, amount))

    def balance(self, account):
        if self._balance is None:
            self._balance = {}
            for entry_account, amount in self._entries:
                self._balance[entry_account] = self._balance.get(entry_account, 0) + amount
        return self._balance.get(account, 0)
PY

cat > ledger/report.py <<'PY'
from ledger.cache import LedgerCache


def account_summary(entries, account):
    cache = LedgerCache()
    for entry_account, amount in entries:
        cache.add(entry_account, amount)
    before = cache.balance(account)
    cache.add(account, 25)
    after = cache.balance(account)
    return {"before": before, "after": after, "delta": after - before}
PY

cat > ledger/__init__.py <<'PY'
PY

cat > tests/test_report.py <<'PY'
import unittest

from ledger.report import account_summary


class ReportTests(unittest.TestCase):
    def test_existing_balance_is_reported(self):
        summary = account_summary([("ops", 10), ("sales", 3), ("ops", -4)], "ops")
        self.assertEqual(summary["before"], 6)

    def test_added_entry_changes_reported_balance(self):
        summary = account_summary([("ops", 10), ("sales", 3), ("ops", -4)], "ops")
        self.assertEqual(summary["after"], 31)
        self.assertEqual(summary["delta"], 25)

    def test_new_account_entry_is_visible(self):
        summary = account_summary([("sales", 3)], "ops")
        self.assertEqual(summary["before"], 0)
        self.assertEqual(summary["after"], 25)


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
