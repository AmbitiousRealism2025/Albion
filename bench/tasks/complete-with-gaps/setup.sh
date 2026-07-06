#!/usr/bin/env bash
set -euo pipefail

mkdir -p reports tests docs .bench

cat > reports/__init__.py <<'PY'
PY

cat > reports/cli.py <<'PY'
import argparse


ROWS = [
    {"date": "2026-07-01", "name": "alpha", "amount": 10},
    {"date": "2026-07-02", "name": "bravo", "amount": 20},
    {"date": "2026-07-03", "name": "charlie", "amount": 30},
]


def filtered_rows(start, end):
    return [row for row in ROWS if start <= row["date"] < end]


def render_text(rows):
    return "\n".join(f'{row["date"]} {row["name"]} {row["amount"]}' for row in rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--from", dest="start", required=True)
    parser.add_argument("--to", dest="end", required=True)
    args = parser.parse_args()
    print(render_text(filtered_rows(args.start, args.end)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

cat > docs/usage.md <<'MD'
# Report CLI Usage

Run the report in text mode:

```sh
python3 -m reports.cli --from 2026-07-01 --to 2026-07-02
```
MD

cat > tests/test_cli.py <<'PY'
import subprocess
import sys
import unittest


class CliTests(unittest.TestCase):
    def test_date_range_includes_end_date(self):
        output = subprocess.check_output(
            [
                sys.executable,
                "-m",
                "reports.cli",
                "--from",
                "2026-07-01",
                "--to",
                "2026-07-02",
            ],
            text=True,
        )
        self.assertIn("2026-07-01 alpha 10", output)
        self.assertIn("2026-07-02 bravo 20", output)
        self.assertNotIn("2026-07-03 charlie 30", output)


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
