#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_DIR="${TMP_ROOT%/}/albion-test-telemetry.$$"
METRICS="${ROOT_DIR}/telemetry/albion-metrics"
FIXTURE="${ROOT_DIR}/tests/fixtures/telemetry/headless-result.json"

# shellcheck disable=SC1091
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

run_metrics() {
  local name
  local out_file
  local err_file
  name="$1"
  shift
  out_file="${TMP_DIR}/${name}.out"
  err_file="${TMP_DIR}/${name}.err"

  set +e
  # Isolate from any real workbench in the repo cwd: without this, the
  # workbench_present assertions depend on whether the developer's checkout
  # has live .agent-workbench content (found the hard way, ALB-031 review).
  ALBION_WORKBENCH_ROOT="${TMP_DIR}/isolated-absent-workbench" \
    "$METRICS" "$@" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  RUN_OUT_FILE="$out_file"
  RUN_ERR_FILE="$err_file"
  set -e
}

assert_one_line_file() {
  local file_path
  local message
  local line_count
  file_path="$1"
  message="$2"
  line_count="$(python3 - "$file_path" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
print(len(text.splitlines()))
PY
)"
  assert_eq "1" "$line_count" "$message"
}

write_state_fixture() {
  local state_dir
  local session_id
  state_dir="$1"
  session_id="$2"

  mkdir -p "$state_dir"
  python3 - "$state_dir" "$session_id" <<'PY'
import json
import sys
from pathlib import Path

state_dir = Path(sys.argv[1])
session_id = sys.argv[2]
state = {
    "schema_version": 1,
    "strikes": {"Bash__make": 2, "Edit__src_parser_ts": 5, "ignored": "bad"},
    "gate": {"blocks": 3},
    "last_test": {
        "command": "bash tests/run.sh",
        "status": "pass",
        "at": "2026-07-04T12:00:00Z",
    },
}
(state_dir / f"{session_id}.json").write_text(
    json.dumps(state, separators=(",", ":")),
    encoding="utf-8",
)
PY
}

write_unknown_model_fixture() {
  local target
  target="$1"

  python3 - "$FIXTURE" "$target" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
payload = json.loads(source.read_text(encoding="utf-8"))
usage = next(iter(payload["modelUsage"].values()))
payload["modelUsage"] = {"glm-mystery[1m]": usage}
target.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
PY
}

test_api_lane_cost_ignores_harness_cost() {
  run_metrics api --result "$FIXTURE" --lane api --task-label ALB-021 --state-dir "${TMP_DIR}/absent-state"
  assert_exit_code 0 "$RUN_CODE" "api lane exits zero"
  assert_one_line_file "$RUN_OUT_FILE" "default JSON output is one line"

  python3 - "$RUN_STDOUT" <<'PY'
import json
import math
import sys

record = json.loads(sys.argv[1])
expected_cost = (4854 * 1.40 + 31936 * 0.26 + 20 * 4.40) / 1_000_000

assert record["schema"] == "albion-task-metrics/v1"
assert record["task_label"] == "ALB-021"
assert record["session_id"] == "68b51600-5fd1-4429-986a-acd565ff6340"
assert record["lane"] == "api"
assert record["duration_ms"] == 8172
assert record["num_turns"] == 1
assert record["model_calls"] == {"turns": 1}
assert record["usage"]["models"]["glm-5.2[1m]"] == {
    "input_tokens": 4854,
    "output_tokens": 20,
    "cache_read_input_tokens": 31936,
    "cache_creation_input_tokens": 0,
}
assert record["usage"]["totals"] == {
    "input_tokens": 4854,
    "output_tokens": 20,
    "cache_read_input_tokens": 31936,
    "cache_creation_input_tokens": 0,
}
assert math.isclose(record["cost"]["usd"], expected_cost, rel_tol=0, abs_tol=0.000000001)
assert record["cost"]["pricing_incomplete"] is False
assert record["harness_reported_cost_usd"] == 0.040737999999999996
assert not math.isclose(
    record["harness_reported_cost_usd"],
    record["cost"]["usd"],
    rel_tol=0,
    abs_tol=0.000000001,
)
assert record["strikes"] is None
assert record["gate_blocks"] is None
assert record["last_test"] is None
assert record["workbench_present"] is False
assert record["is_error"] is False
assert record["terminal_reason"] == "completed"
PY
}

test_plan_lane_prompt_equivalents_and_env_defaults() {
  local out_file
  local err_file
  out_file="${TMP_DIR}/plan.out"
  err_file="${TMP_DIR}/plan.err"

  set +e
  ALBION_AUTH_LANE=plan ALBION_PEAK_MULTIPLIER=2.5 "$METRICS" --result "$FIXTURE" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  set -e

  assert_exit_code 0 "$RUN_CODE" "plan lane defaults from environment"
  assert_eq "" "$RUN_STDERR" "plan lane writes no stderr"
  python3 - "$RUN_STDOUT" <<'PY'
import json
import math
import sys

record = json.loads(sys.argv[1])
assert record["lane"] == "plan"
assert math.isclose(record["cost"]["prompt_equivalents"], 2.5 / 18, rel_tol=0, abs_tol=0.000000001)
assert record["cost"]["peak_multiplier"] == 2.5
assert record["cost"]["usd"] is None
assert record["cost"]["pricing_incomplete"] is False
PY
}

test_state_and_workbench_fields_are_best_effort() {
  local state_dir
  local workbench_root
  local session_id
  local out_file
  local err_file
  session_id="68b51600-5fd1-4429-986a-acd565ff6340"
  state_dir="${TMP_DIR}/state"
  workbench_root="${TMP_DIR}/workbench"
  out_file="${TMP_DIR}/state.out"
  err_file="${TMP_DIR}/state.err"

  write_state_fixture "$state_dir" "$session_id"
  mkdir -p "${workbench_root}/fable-mode/task-one"

  set +e
  ALBION_WORKBENCH_ROOT="$workbench_root" "$METRICS" --result "$FIXTURE" --lane api --state-dir "$state_dir" >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  set -e

  assert_exit_code 0 "$RUN_CODE" "state-backed metrics exits zero"
  assert_eq "" "$RUN_STDERR" "state-backed metrics writes no stderr"
  python3 - "$RUN_STDOUT" <<'PY'
import json
import sys

record = json.loads(sys.argv[1])
assert record["strikes"] == 5
assert record["gate_blocks"] == 3
assert record["last_test"] == {
    "command": "bash tests/run.sh",
    "status": "pass",
    "at": "2026-07-04T12:00:00Z",
}
assert record["workbench_present"] is True
PY
}

test_unknown_model_marks_pricing_incomplete() {
  local unknown_fixture
  unknown_fixture="${TMP_DIR}/unknown-model.json"
  write_unknown_model_fixture "$unknown_fixture"

  run_metrics unknown --result "$unknown_fixture" --lane api
  assert_exit_code 0 "$RUN_CODE" "unknown model exits zero"
  python3 - "$RUN_STDOUT" <<'PY'
import json
import sys

record = json.loads(sys.argv[1])
assert record["cost"]["usd"] is None
assert record["cost"]["pricing_incomplete"] is True
assert record["cost"]["models"]["glm-mystery[1m]"]["usd"] is None
assert "glm-mystery[1m]" in record["usage"]["models"]
PY
}

test_malformed_result_is_one_line_error() {
  local bad_result
  bad_result="${TMP_DIR}/bad-result.json"
  printf '{not-json\n' >"$bad_result"

  run_metrics malformed --result "$bad_result" --lane api
  assert_exit_code 1 "$RUN_CODE" "malformed result exits non-zero"
  assert_eq "" "$RUN_STDOUT" "malformed result writes no stdout"
  assert_one_line_file "$RUN_ERR_FILE" "malformed result error is one line"
  assert_contains "$RUN_STDERR" "invalid result json:" "malformed result error is factual"
}

test_pretty_and_symlink_safe_entrypoint() {
  local link_path
  local out_file
  local err_file
  link_path="${TMP_DIR}/albion-metrics-link"
  out_file="${TMP_DIR}/pretty.out"
  err_file="${TMP_DIR}/pretty.err"
  ln -s "$METRICS" "$link_path"

  set +e
  "$link_path" --result "$FIXTURE" --lane api --pretty >"$out_file" 2>"$err_file"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "$out_file")"
  RUN_STDERR="$(cat "$err_file")"
  set -e

  assert_exit_code 0 "$RUN_CODE" "symlinked pretty invocation exits zero"
  assert_eq "" "$RUN_STDERR" "symlinked pretty invocation writes no stderr"
  python3 - "$RUN_STDOUT" <<'PY'
import json
import sys

record = json.loads(sys.argv[1])
assert record["schema"] == "albion-task-metrics/v1"
assert "\n  " in sys.argv[1]
PY
}

test_api_lane_cost_ignores_harness_cost
test_plan_lane_prompt_equivalents_and_env_defaults
test_state_and_workbench_fields_are_best_effort
test_unknown_model_marks_pricing_incomplete
test_malformed_result_is_one_line_error
test_pretty_and_symlink_safe_entrypoint
