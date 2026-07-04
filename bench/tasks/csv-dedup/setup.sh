#!/usr/bin/env bash
set -euo pipefail

mkdir -p csvtools tests

cat > csvtools/dedup.py <<'PY'
import csv
from io import StringIO


def unique_emails(rows):
    return sorted({row["email"].strip().lower() for row in rows if row.get("email", "").strip()})


def dedup_csv(text):
    reader = csv.DictReader(StringIO(text))
    rows = list(reader)
    keep = set(unique_emails(rows))
    output = StringIO()
    writer = csv.DictWriter(output, fieldnames=reader.fieldnames or [])
    writer.writeheader()
    for email in keep:
        for row in rows:
            if row["email"].strip().lower() == email:
                row = dict(row)
                row["email"] = email
                writer.writerow(row)
                break
    return output.getvalue()
PY

cat > csvtools/__init__.py <<'PY'
PY

cat > tests/test_dedup.py <<'PY'
import csv
import unittest
from io import StringIO
from csvtools.dedup import dedup_csv, unique_emails


ROWS = [
    {"name": "A", "email": "one@example.com"},
    {"name": "B", "email": "two@example.com"},
    {"name": "C", "email": "ONE@example.com"},
    {"name": "D", "email": "three@example.com"},
]


def parse(text):
    return list(csv.DictReader(StringIO(text)))


class DedupTests(unittest.TestCase):
    def test_unique_emails_normalizes_values(self):
        self.assertEqual(set(unique_emails(ROWS)), {"one@example.com", "two@example.com", "three@example.com"})

    def test_unique_emails_preserves_first_seen_order(self):
        self.assertEqual(unique_emails(ROWS), ["one@example.com", "two@example.com", "three@example.com"])

    def test_dedup_csv_removes_later_duplicates(self):
        output = dedup_csv("name,email\nA,one@example.com\nB,ONE@example.com\n")
        self.assertEqual(parse(output), [{"name": "A", "email": "one@example.com"}])

    def test_dedup_csv_preserves_input_order_of_kept_rows(self):
        output = dedup_csv("name,email\nB,two@example.com\nA,one@example.com\nC,TWO@example.com\n")
        self.assertEqual([row["name"] for row in parse(output)], ["B", "A"])


if __name__ == "__main__":
    unittest.main()
PY
