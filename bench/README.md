# Bench Tasks

`bench/run-task` executes one task under one arm, runs the task oracle, and
writes a canonical record for later review.

```bash
bench/run-task --task bench/tasks/<id> --arm albion|vanilla --out <dir>
```

`--out` must not already exist. The runner creates `<out>/workspace`, runs the
task there, and leaves it intact. Tests set `ALBION_BENCH_LAUNCHER` to a stub;
normal runs default to `bin/albion`.

## Task Directory

Each task directory contains:

- `task.md`: natural prompt sent to the model. Do not coach the loop; routing is
  part of the measurement.
- `setup.sh`: seeds a fresh workspace. Runs with the workspace as cwd.
- `verify.sh`: model-independent oracle. Runs with the workspace as cwd after
  the model session; exit 0 means solved.
- `allowed-tools`: one Claude `--allowedTools` specifier per line, for example
  `Bash(python3:*)`.

## Launch Contract

The runner launches:

```text
${ALBION_BENCH_LAUNCHER:-<repo>/bin/albion} -p "$(cat task.md)" \
  --permission-mode acceptEdits --output-format json \
  --allowedTools "<line from allowed-tools>"
```

`--arm vanilla` appends `--vanilla`. Launcher stdout is saved to
`<out>/result.json`. The runner then calls `telemetry/albion-metrics --result`
and embeds that record verbatim.

## Run Record

`<out>/run-record.json` uses schema `albion-bench-run/v2`:

```json
{
  "schema": "albion-bench-run/v2",
  "task_id": "ledger-cache",
  "arm": "albion",
  "solved": true,
  "verify_exit": 0,
  "metrics": {"schema": "albion-task-metrics/v1"},
  "manifest": null,
  "workbench_present": true,
  "workbench": {
    "engaged": true,
    "evidence_complete": true,
    "tasks": [
      {
        "slug": "fix-pipeline",
        "files": [
          {"name": "task.md", "bytes": 812},
          {"name": "verification.md", "bytes": 1430}
        ]
      }
    ],
    "lessons_file_count": 0
  },
  "started_at": "2026-07-04T12:00:00Z",
  "wall_seconds": 0
}
```

`manifest` is the workspace `.albion/completion-manifest.json` object when
present and valid JSON, otherwise `null`. `workbench_present` is true when the
workspace has any `.agent-workbench/fable-mode/` task directories other than
`lessons`; it is retained in v2 for continuity.

The v2 `workbench` object records the board artifacts left by the session:

- `engaged`: same predicate as `workbench_present`.
- `tasks`: one entry per `.agent-workbench/fable-mode/<task-slug>/` directory
  other than `lessons`, sorted by slug. Each entry lists the regular files
  directly inside that task directory, sorted by name, with byte sizes.
- `evidence_complete`: true only when the board is engaged and every task
  directory has non-whitespace content in both `task.md` and `verification.md`.
- `lessons_file_count`: count of regular files under
  `.agent-workbench/fable-mode/lessons/`.

`bench/report` accepts both v1 and v2 run records. The per-task table includes
an `evidence` column: v1-only cells render `n/a`, while v2 cells show the
evidence-complete rate over records that carry `workbench.evidence_complete`.
The per-arm table includes `evidence_complete_rate` with the same denominator
rule; arms with no v2 evidence data render `0/0 (n/a)`.
