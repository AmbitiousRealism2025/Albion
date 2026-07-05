#!/usr/bin/env bash
set -euo pipefail

mkdir -p bank tests .bench

cat > bank/__init__.py <<'PY'
PY

cat > bank/gateway.py <<'PY'
"""External write gateway.

Each entry's first write fails with a transient error and the second succeeds.
Deterministic (a per-entry attempt counter), so the suite is stable.
"""


class TransientError(Exception):
    pass


class Gateway:
    def __init__(self):
        self._attempts = {}

    def commit(self, entry_id, account, amount):
        count = self._attempts.get(entry_id, 0) + 1
        self._attempts[entry_id] = count
        if count == 1:
            raise TransientError(f"transient failure writing {entry_id}")
        return True
PY

cat > bank/events.py <<'PY'
"""Event builders.

A deposit is a single entry. A transfer is two entries -- a debit and a credit
-- that belong to the same client request and therefore share a request_id,
while each still carries its own entry_id.
"""


def deposit(request_id, account, amount):
    return [
        {
            "request_id": request_id,
            "entry_id": f"{request_id}:main",
            "account": account,
            "amount": amount,
        },
    ]


def transfer(request_id, source, dest, amount):
    return [
        {
            "request_id": request_id,
            "entry_id": f"{request_id}:debit",
            "account": source,
            "amount": -amount,
        },
        {
            "request_id": request_id,
            "entry_id": f"{request_id}:credit",
            "account": dest,
            "amount": amount,
        },
    ]
PY

cat > bank/ledger.py <<'PY'
"""Idempotent ledger with a retrying external write and a balance cache."""

from bank.gateway import Gateway, TransientError

MAX_ATTEMPTS = 3


class Ledger:
    def __init__(self):
        self._gateway = Gateway()
        self._entries = []
        self._seen = set()
        self._cache = {}
        self._cache_dirty = True

    def _commit_with_retry(self, entry):
        for attempt in range(MAX_ATTEMPTS):
            try:
                self._gateway.commit(entry["entry_id"], entry["account"], entry["amount"])
                return
            except TransientError:
                if attempt == MAX_ATTEMPTS - 1:
                    raise

    def _apply(self, entry):
        # Skip entries already applied, so a retried request is not double-counted.
        dedup_key = entry["request_id"]
        if dedup_key in self._seen:
            return
        self._commit_with_retry(entry)
        self._seen.add(dedup_key)
        self._entries.append((entry["account"], entry["amount"]))
        self._cache_dirty = True

    def process(self, events):
        for entry in events:
            self._apply(entry)

    def _rebuild_cache(self):
        self._cache = {}
        for account, amount in self._entries:
            self._cache[account] = self._cache.get(account, 0) + amount
        self._cache_dirty = False

    def balance(self, account):
        if self._cache_dirty:
            self._rebuild_cache()
        return self._cache.get(account, 0)
PY

cat > bank/report.py <<'PY'
"""Downstream reporting over a ledger."""


def account_summary(ledger, accounts):
    return {account: ledger.balance(account) for account in accounts}


def net_total(ledger, accounts):
    return sum(ledger.balance(account) for account in accounts)
PY

cat > tests/test_ledger.py <<'PY'
import unittest

from bank.events import deposit, transfer
from bank.ledger import Ledger
from bank.report import net_total


def run(*event_batches):
    ledger = Ledger()
    for batch in event_batches:
        ledger.process(batch)
    return ledger


class LedgerTests(unittest.TestCase):
    def test_single_deposit_survives_retry(self):
        ledger = run(deposit("r1", "alice", 100))
        self.assertEqual(ledger.balance("alice"), 100)

    def test_repeated_deposits_accumulate(self):
        ledger = run(deposit("r1", "alice", 40), deposit("r2", "alice", 60))
        self.assertEqual(ledger.balance("alice"), 100)

    def test_resubmitted_request_is_ignored(self):
        batch = deposit("r1", "alice", 100)
        ledger = run(batch, batch)  # client re-sent the identical request
        self.assertEqual(ledger.balance("alice"), 100)

    def test_transfer_credits_destination(self):
        ledger = run(deposit("r0", "alice", 100), transfer("r1", "alice", "bob", 30))
        self.assertEqual(ledger.balance("alice"), 70)
        self.assertEqual(ledger.balance("bob"), 30)

    def test_transfer_conserves_money(self):
        ledger = run(deposit("r0", "alice", 100), transfer("r1", "alice", "bob", 30))
        self.assertEqual(net_total(ledger, ["alice", "bob"]), 100)

    def test_cache_reflects_new_entries(self):
        ledger = run(deposit("r0", "alice", 10))
        self.assertEqual(ledger.balance("alice"), 10)
        ledger.process(deposit("r1", "alice", 5))
        self.assertEqual(ledger.balance("alice"), 15)


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
