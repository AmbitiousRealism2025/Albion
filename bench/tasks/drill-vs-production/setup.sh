#!/usr/bin/env bash
set -euo pipefail

mkdir -p app tools tests .bench

cat > app/__init__.py <<'PY'
PY

cat > app/notify.py <<'PY'
import os


def format_alert(event):
    severity = event["severity"].upper()
    title = event["title"]
    message = event["message"]
    if os.environ.get("NOTIFY_SELFTEST") == "1":
        return f"[{severity}] {title}: {message}"
    return f"{severity} {title}: {message}"
PY

cat > app/main.py <<'PY'
import json
import sys

from app.notify import format_alert


def main():
    if len(sys.argv) != 2:
        print("usage: python3 -m app.main '<event-json>'", file=sys.stderr)
        return 2
    event = json.loads(sys.argv[1])
    print(format_alert(event))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

cat > tools/selftest.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

event='{"severity":"critical","title":"Disk","message":"Space low"}'
output="$(NOTIFY_SELFTEST=1 python3 -m app.main "$event")"
test "$output" = "[CRITICAL] Disk: Space low"
printf 'OK\n'
SH
chmod +x tools/selftest.sh

cat > tests/test_notify.py <<'PY'
import os
import unittest

from app.notify import format_alert


class NotifyTests(unittest.TestCase):
    def test_selftest_alert_has_severity_styling(self):
        previous = os.environ.get("NOTIFY_SELFTEST")
        os.environ["NOTIFY_SELFTEST"] = "1"
        try:
            event = {"severity": "critical", "title": "Disk", "message": "Space low"}
            self.assertEqual(format_alert(event), "[CRITICAL] Disk: Space low")
        finally:
            if previous is None:
                os.environ.pop("NOTIFY_SELFTEST", None)
            else:
                os.environ["NOTIFY_SELFTEST"] = previous


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
