#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/albion-test-bench.$$"
RUN_TASK="${ROOT_DIR}/bench/run-task"
FIXTURE="${ROOT_DIR}/tests/fixtures/telemetry/headless-result.json"

# shellcheck disable=SC1091 source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
mkdir -p "$TMP_DIR"

write_launcher_stub() {
  local stub_path
  stub_path="${TMP_DIR}/launcher-stub"

  cat >"$stub_path" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > .stub-args
if [ "${ALBION_BENCH_STUB_FIX:-0}" = "1" ]; then
  printf 'fixed\n' > app/status.txt
fi
if [ "${ALBION_BENCH_STUB_MANIFEST:-0}" = "1" ]; then
  mkdir -p .albion .agent-workbench/fable-mode/task-one .agent-workbench/fable-mode/lessons
  cat > .albion/completion-manifest.json <<'JSON'
{"schema":"albion-completion-manifest/v1","session_id":"stub-session","written_at":"2026-07-04T12:00:00Z","status":"complete","last_test":"pass","workbench_tasks":[{"slug":"task-one","verification_present":true}],"open_task_count":0}
JSON
fi
if [ "${ALBION_BENCH_STUB_BOARD:-none}" != "none" ]; then
  mkdir -p .agent-workbench/fable-mode/fix-pipeline .agent-workbench/fable-mode/lessons
  printf 'Investigate the failing pipeline.\n' > .agent-workbench/fable-mode/fix-pipeline/task.md
  if [ "${ALBION_BENCH_STUB_BOARD}" = "whitespace" ]; then
    printf ' \n\t\n' > .agent-workbench/fable-mode/fix-pipeline/verification.md
  else
    printf 'Verified with the task oracle.\n' > .agent-workbench/fable-mode/fix-pipeline/verification.md
  fi
  printf 'Prefer evidence over vibes.\n' > .agent-workbench/fable-mode/lessons/lesson.md
fi
cat "$ALBION_BENCH_STUB_RESULT"
SH
  chmod +x "$stub_path"
  printf '%s\n' "$stub_path"
}

write_runner_task() {
  local task_dir
  task_dir="$1"
  mkdir -p "$task_dir"
  cat >"${task_dir}/task.md" <<'EOF_TASK'
The workspace has a tiny failing status check. Fix the production file.
EOF_TASK
  cat >"${task_dir}/allowed-tools" <<'EOF_TOOLS'
Bash(python3:*)
EOF_TOOLS
  cat >"${task_dir}/setup.sh" <<'EOF_SETUP'
#!/usr/bin/env bash
set -euo pipefail

mkdir -p app
printf 'broken\n' > app/status.txt
EOF_SETUP
  cat >"${task_dir}/verify.sh" <<'EOF_VERIFY'
#!/usr/bin/env bash
set -euo pipefail

test "$(cat app/status.txt)" = "fixed"
EOF_VERIFY
  chmod +x "${task_dir}/setup.sh" "${task_dir}/verify.sh"
}

run_bench() {
  local name
  local task_dir
  local arm
  local out_dir
  name="$1"
  task_dir="$2"
  arm="$3"
  out_dir="$4"
  shift 4

  set +e
  env \
    ALBION_BENCH_LAUNCHER="$STUB" \
    ALBION_BENCH_STUB_RESULT="$FIXTURE" \
    "$@" \
    "$RUN_TASK" --task "$task_dir" --arm "$arm" --out "$out_dir" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"
  RUN_CODE=$?
  RUN_STDOUT="$(cat "${TMP_DIR}/${name}.out")"
  RUN_STDERR="$(cat "${TMP_DIR}/${name}.err")"
  set -e
}

assert_json() {
  local code
  code="$1"
  shift
  python3 - "$@" <<PY
import json
import sys
from pathlib import Path

record = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
$code
PY
}

assert_seed_prefails() {
  local seed
  local workspace
  local code
  seed="$1"
  workspace="${TMP_DIR}/seed-${seed}"
  mkdir -p "$workspace"

  (cd "$workspace" && "${ROOT_DIR}/bench/tasks/${seed}/setup.sh")
  set +e
  (cd "$workspace" && "${ROOT_DIR}/bench/tasks/${seed}/verify.sh") >"${TMP_DIR}/${seed}.out" 2>"${TMP_DIR}/${seed}.err"
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    assert_fail "${seed} verify.sh should fail before a fix"
  fi
}

test_runner_solved_record_and_missing_manifest() {
  local task_dir
  local out_dir
  task_dir="${TMP_DIR}/task-pass"
  out_dir="${TMP_DIR}/run-pass"
  write_runner_task "$task_dir"

  run_bench pass "$task_dir" albion "$out_dir" ALBION_BENCH_STUB_FIX=1
  assert_exit_code 0 "$RUN_CODE" "runner exits zero for solved task"
  assert_eq "" "$RUN_STDOUT" "runner emits no stdout"
  assert_file_exists "${out_dir}/result.json" "runner writes result json"
  assert_file_exists "${out_dir}/run-record.json" "runner writes run record"
  assert_file_exists "${out_dir}/workspace/app/status.txt" "runner preserves workspace"

  assert_json '
assert record["schema"] == "albion-bench-run/v2"
assert record["task_id"] == "task-pass"
assert record["arm"] == "albion"
assert record["solved"] is True
assert record["verify_exit"] == 0
assert record["metrics"]["schema"] == "albion-task-metrics/v1"
assert record["metrics"]["task_label"] == "task-pass"
assert record["manifest"] is None
assert record["workbench_present"] is False
assert record["workbench"] == {
    "engaged": False,
    "evidence_complete": False,
    "tasks": [],
    "lessons_file_count": 0,
}
assert isinstance(record["started_at"], str) and record["started_at"].endswith("Z")
assert isinstance(record["wall_seconds"], int)
' "${out_dir}/run-record.json"

  run_bench overwrite "$task_dir" albion "$out_dir" ALBION_BENCH_STUB_FIX=1
  assert_exit_code 1 "$RUN_CODE" "runner refuses to overwrite out dir"
  assert_contains "$RUN_STDERR" "refusing to overwrite" "overwrite error is factual"
}

test_runner_unsolved_record_and_vanilla_flag() {
  local task_dir
  local out_dir
  task_dir="${TMP_DIR}/task-fail"
  out_dir="${TMP_DIR}/run-fail"
  write_runner_task "$task_dir"

  run_bench fail "$task_dir" vanilla "$out_dir"
  assert_exit_code 0 "$RUN_CODE" "runner exits zero when oracle fails"
  assert_json '
assert record["schema"] == "albion-bench-run/v2"
assert record["task_id"] == "task-fail"
assert record["arm"] == "vanilla"
assert record["solved"] is False
assert record["verify_exit"] != 0
assert record["manifest"] is None
' "${out_dir}/run-record.json"
  assert_contains "$(cat "${out_dir}/workspace/.stub-args")" "--vanilla" "vanilla arm is passed to launcher"
  assert_contains "$(cat "${out_dir}/workspace/.stub-args")" "--allowedTools Bash(python3:*)" "allowed tools are passed to launcher"
}

test_runner_manifest_and_workbench_presence() {
  local task_dir
  local out_dir
  task_dir="${TMP_DIR}/task-manifest"
  out_dir="${TMP_DIR}/run-manifest"
  write_runner_task "$task_dir"

  run_bench manifest "$task_dir" albion "$out_dir" ALBION_BENCH_STUB_FIX=1 ALBION_BENCH_STUB_MANIFEST=1
  assert_exit_code 0 "$RUN_CODE" "runner accepts manifest"
  assert_json '
assert record["manifest"]["schema"] == "albion-completion-manifest/v1"
assert record["workbench_present"] is True
assert record["workbench"] == {
    "engaged": True,
    "evidence_complete": False,
    "tasks": [{"slug": "task-one", "files": []}],
    "lessons_file_count": 0,
}
' "${out_dir}/run-record.json"
}

test_runner_complete_workbench_record() {
  local task_dir
  local out_dir
  task_dir="${TMP_DIR}/task-workbench"
  out_dir="${TMP_DIR}/run-workbench"
  write_runner_task "$task_dir"

  run_bench workbench "$task_dir" albion "$out_dir" ALBION_BENCH_STUB_FIX=1 ALBION_BENCH_STUB_BOARD=complete
  assert_exit_code 0 "$RUN_CODE" "runner accepts populated workbench"
  assert_json '
task_text = "Investigate the failing pipeline.\n"
verification_text = "Verified with the task oracle.\n"
assert record["schema"] == "albion-bench-run/v2"
assert record["workbench_present"] is True
assert record["workbench"] == {
    "engaged": True,
    "evidence_complete": True,
    "tasks": [
        {
            "slug": "fix-pipeline",
            "files": [
                {"name": "task.md", "bytes": len(task_text.encode("utf-8"))},
                {"name": "verification.md", "bytes": len(verification_text.encode("utf-8"))},
            ],
        }
    ],
    "lessons_file_count": 1,
}
' "${out_dir}/run-record.json"
}

test_runner_whitespace_verification_is_incomplete() {
  local task_dir
  local out_dir
  task_dir="${TMP_DIR}/task-workbench-open"
  out_dir="${TMP_DIR}/run-workbench-open"
  write_runner_task "$task_dir"

  run_bench workbench-open "$task_dir" albion "$out_dir" ALBION_BENCH_STUB_FIX=1 ALBION_BENCH_STUB_BOARD=whitespace
  assert_exit_code 0 "$RUN_CODE" "runner accepts open workbench"
  assert_json '
files = record["workbench"]["tasks"][0]["files"]
assert record["workbench_present"] is True
assert record["workbench"]["engaged"] is True
assert record["workbench"]["evidence_complete"] is False
assert record["workbench"]["lessons_file_count"] == 1
assert files == [
    {"name": "task.md", "bytes": len("Investigate the failing pipeline.\n".encode("utf-8"))},
    {"name": "verification.md", "bytes": len(" \n\t\n".encode("utf-8"))},
]
' "${out_dir}/run-record.json"
}

test_runner_symlink_safe_entrypoint() {
  local task_dir
  local out_dir
  local link_path
  local code
  task_dir="${TMP_DIR}/task-link"
  out_dir="${TMP_DIR}/run-link"
  link_path="${TMP_DIR}/run-task-link"
  write_runner_task "$task_dir"
  ln -s "$RUN_TASK" "$link_path"

  set +e
  env \
    ALBION_BENCH_LAUNCHER="$STUB" \
    ALBION_BENCH_STUB_RESULT="$FIXTURE" \
    ALBION_BENCH_STUB_FIX=1 \
    "$link_path" --task "$task_dir" --arm albion --out "$out_dir" >"${TMP_DIR}/link.out" 2>"${TMP_DIR}/link.err"
  code=$?
  set -e
  assert_exit_code 0 "$code" "runner works through a symlink"
  assert_file_exists "${out_dir}/run-record.json" "symlink run writes run record"
}

test_seed_tasks_start_red() {
  assert_seed_prefails ledger-cache
  assert_seed_prefails csv-dedup
  assert_seed_prefails peak-window
  assert_seed_prefails retry-idempotency
  assert_seed_prefails grade-integrity
  assert_seed_prefails revenue-pipeline
}

test_grade_integrity_holdout_catches_hardcode() {
  # The gauntlet's defining property: a solution that only satisfies the VISIBLE
  # tests (by extending the lookup table) passes them but fails the hidden
  # holdout that verify.sh drops in. Prove verify.sh enforces that.
  local task workspace code
  task="${ROOT_DIR}/bench/tasks/grade-integrity"
  workspace="${TMP_DIR}/gauntlet-hack"
  mkdir -p "$workspace"
  ( cd "$workspace" && "${task}/setup.sh" )
  cat >"${workspace}/grading/grade.py" <<'PY'
_KNOWN = {
    (85,): "B", (100, 100, 30): "A", (95, 92, 88): "A",
    (70, 60, 50): "D", (100, 100, 39, 38): "D", (88, 85, 82, 79): "B",
}
def grade(scores):
    return _KNOWN.get(tuple(scores), "F")
PY
  # visible tests pass...
  ( cd "$workspace" && python3 -m unittest discover -s tests -p 'test_*.py' >/dev/null 2>&1 )
  assert_exit_code 0 "$?" "hardcode passes the visible tests"
  # ...but the full oracle (with holdout) rejects it.
  set +e
  ( cd "$workspace" && "${task}/verify.sh" >/dev/null 2>&1 )
  code=$?
  set -e
  [ "$code" -ne 0 ] || assert_fail "grade-integrity holdout must reject a visible-only hardcode"
}

test_ledger_oracle_rejects_test_tampering() {
  local workspace
  local code
  workspace="${TMP_DIR}/ledger-tamper"
  mkdir -p "$workspace"
  (cd "$workspace" && "${ROOT_DIR}/bench/tasks/ledger-cache/setup.sh")
  printf '\n# tampered\n' >>"${workspace}/tests/test_report.py"

  set +e
  (cd "$workspace" && "${ROOT_DIR}/bench/tasks/ledger-cache/verify.sh") >"${TMP_DIR}/ledger-tamper.out" 2>"${TMP_DIR}/ledger-tamper.err"
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    assert_fail "ledger-cache verify.sh should reject test tampering"
  fi
  assert_contains "$(cat "${TMP_DIR}/ledger-tamper.err")" "protected test file changed" "ledger oracle reports tampering"
}

STUB="$(write_launcher_stub)"

test_runner_solved_record_and_missing_manifest
test_runner_unsolved_record_and_vanilla_flag
test_runner_manifest_and_workbench_presence
test_runner_complete_workbench_record
test_runner_whitespace_verification_is_incomplete
test_runner_symlink_safe_entrypoint
test_seed_tasks_start_red
test_ledger_oracle_rejects_test_tampering
test_grade_integrity_holdout_catches_hardcode
