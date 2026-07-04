#!/usr/bin/env bash
set -euo pipefail

mkdir -p windows tests

cat > windows/peaks.py <<'PY'
def label_for_minute(minute):
    if minute < 0 or minute > 24 * 60:
        raise ValueError("minute outside day")
    if 9 * 60 < minute < 17 * 60:
        return "peak"
    return "off"


def count_peak(events):
    return sum(1 for event in events if label_for_minute(event["minute"]) == "peak")


def format_event(event):
    return f'{event["id"]}@{event["minute"]}'
PY

cat > windows/__init__.py <<'PY'
PY

cat > tests/test_peaks.py <<'PY'
import unittest

from windows.peaks import count_peak, format_event, label_for_minute


class PeakTests(unittest.TestCase):
    def test_middle_of_window_is_peak(self):
        self.assertEqual(label_for_minute(12 * 60), "peak")

    def test_peak_window_includes_start_boundary(self):
        self.assertEqual(label_for_minute(9 * 60), "peak")

    def test_peak_window_excludes_end_boundary(self):
        self.assertEqual(label_for_minute(17 * 60), "off")

    def test_counter_uses_same_boundaries(self):
        events = [{"id": "a", "minute": 9 * 60}, {"id": "b", "minute": 17 * 60}, {"id": "c", "minute": 16 * 60}]
        self.assertEqual(count_peak(events), 2)

    def test_red_herring_formatter(self):
        self.assertEqual(format_event({"id": "z", "minute": 42}), "z@42")


if __name__ == "__main__":
    unittest.main()
PY
