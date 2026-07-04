#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/albion-bench-report.XXXXXX")"
REPORT="${ROOT_DIR}/bench/report"

# shellcheck disable=SC1091
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

write_records() {
  local runs_dir
  runs_dir="$1"

  python3 - "$runs_dir" <<'PY'
import json
import sys
from pathlib import Path

runs_dir = Path(sys.argv[1])


def write_record(path, *, task_id, arm, solved, lane, started_at, wall_seconds, turns,
                 cost, pricing_incomplete, gate_blocks, strikes, workbench, manifest_last_test):
    record = {
        "schema": "albion-bench-run/v1",
        "task_id": task_id,
        "arm": arm,
        "solved": solved,
        "verify_exit": 0 if solved else 1,
        "metrics": {
            "schema": "albion-task-metrics/v1",
            "task_label": task_id,
            "session_id": f"{task_id}-{arm}",
            "lane": lane,
            "duration_ms": int(wall_seconds * 1000),
            "num_turns": turns,
            "usage": {"models": {}, "totals": {}},
            "model_calls": {"turns": turns},
            "cost": cost | {"pricing_incomplete": pricing_incomplete},
            "harness_reported_cost_usd": None,
            "strikes": strikes,
            "gate_blocks": gate_blocks,
            "last_test": None,
            "workbench_present": workbench,
            "is_error": False,
            "terminal_reason": "done",
        },
        "manifest": {"schema": "albion-completion-manifest/v1", "last_test": manifest_last_test}
        if manifest_last_test is not None
        else None,
        "workbench_present": workbench,
        "started_at": started_at,
        "wall_seconds": wall_seconds,
    }
    path.mkdir(parents=True, exist_ok=True)
    (path / "run-record.json").write_text(json.dumps(record, sort_keys=True) + "\n", encoding="utf-8")


write_record(
    runs_dir / "alpha" / "albion",
    task_id="alpha",
    arm="albion",
    solved=True,
    lane="api",
    started_at="2026-07-04T10:00:00Z",
    wall_seconds=10,
    turns=4,
    cost={"usd": 0.30},
    pricing_incomplete=False,
    gate_blocks=0,
    strikes=0,
    workbench=True,
    manifest_last_test="pass",
)
write_record(
    runs_dir / "alpha" / "vanilla",
    task_id="alpha",
    arm="vanilla",
    solved=True,
    lane="api",
    started_at="2026-07-04T10:10:00Z",
    wall_seconds=20,
    turns=6,
    cost={"usd": 0.60},
    pricing_incomplete=False,
    gate_blocks=0,
    strikes=0,
    workbench=False,
    manifest_last_test="pass",
)
write_record(
    runs_dir / "beta" / "albion",
    task_id="beta",
    arm="albion",
    solved=False,
    lane="plan",
    started_at="2026-07-04T10:20:00Z",
    wall_seconds=30,
    turns=9,
    cost={"prompt_equivalents": 0.50},
    pricing_incomplete=False,
    gate_blocks=1,
    strikes=2,
    workbench=True,
    manifest_last_test="fail",
)
write_record(
    runs_dir / "beta" / "vanilla",
    task_id="beta",
    arm="vanilla",
    solved=True,
    lane="api",
    started_at="2026-07-04T10:30:00Z",
    wall_seconds=40,
    turns=8,
    cost={"usd": None},
    pricing_incomplete=True,
    gate_blocks=0,
    strikes=0,
    workbench=False,
    manifest_last_test="pass",
)

bad_dir = runs_dir / "bad-schema"
bad_dir.mkdir(parents=True, exist_ok=True)
(bad_dir / "run-record.json").write_text('{"schema":"not-the-schema"}\n', encoding="utf-8")
PY
}

test_report_stdout_contains_expected_values() {
  local runs_dir
  local output
  runs_dir="${TMP_DIR}/runs"
  write_records "$runs_dir"

  output="$("$REPORT" "$runs_dir")"

  assert_contains "$output" "Run counts by arm: albion=2, vanilla=2" "report counts per arm"
  assert_contains "$output" "Lanes: api, plan" "report lists mixed lanes"
  assert_contains "$output" "Date range: 2026-07-04T10:00:00Z to 2026-07-04T10:30:00Z" "report date range"
  assert_contains "$output" "| alpha | albion | 1 | 1/1 | 10 | 4 | 0.3 |  | 0 | 0 | yes |" "alpha albion row"
  assert_contains "$output" "| beta | vanilla | 1 | 1/1 | 40 | 8 | ~ |  | 0 | 0 | no |" "pricing incomplete renders as tilde"
  assert_contains "$output" "| albion | 2 | 1/2 (50%) | 10 (n=1) | 10 (n=1) | 0.3 (n=1) | n/a (n=0) | 2/2 (100%) | 1/2 (50%) | 1/2 (50%) | 1/1 (100%) |" "albion aggregate row"
  assert_contains "$output" "| vanilla | 2 | 2/2 (100%) | 30 (n=2) | 30 (n=2) | 0.6 (n=1) | n/a (n=0) | 0/2 (0%) | 0/2 (0%) | 0/2 (0%) | 2/2 (100%) |" "vanilla aggregate excludes incomplete cost"
  assert_contains "$output" "Single-digit n supports direction, not statistical significance" "honest notes include small-n warning"
  assert_contains "$output" "- beta: albion 0/1, vanilla 1/1" "solved disagreement named"
  assert_contains "$output" "- bad-schema/run-record.json: schema mismatch (expected albion-bench-run/v1)" "schema mismatch is listed"
  assert_contains "$output" "- alpha x albion: n=1" "cell n is listed"
  assert_contains "$output" "solve_rate" "solve rate denominators are explicit"
}

test_report_out_writes_file() {
  local runs_dir
  local out_file
  runs_dir="${TMP_DIR}/runs-out"
  out_file="${TMP_DIR}/report.md"
  write_records "$runs_dir"

  "$REPORT" "$runs_dir" --out "$out_file"

  assert_file_exists "$out_file" "report writes --out file"
  assert_contains "$(cat "$out_file")" "# Albion Bench Report" "written report has header"
  assert_contains "$(cat "$out_file")" "| beta | albion | 1 | 0/1 | 30 | 9 |  | 0.5 | 1 | 2 | yes |" "plan lane cost column is populated"
}

test_report_stdout_contains_expected_values
test_report_out_writes_file
