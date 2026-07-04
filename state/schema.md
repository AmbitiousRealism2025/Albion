# Albion Session-State Schema

Albion session state is a per-session JSON object stored at:

```text
${ALBION_STATE_DIR:-.albion/state}/<session_id>.json
```

Hook payloads provide `session_id`; hooks use that value to choose the state file. The state file is the machine-readable complement to the model-facing workbench. When prose workbench state and session-state JSON disagree, the JSON state wins.

State files are written by `state/albion-state` with mode `0600`. Writes are serialized with a sibling `<file>.lock`, written to a temporary file in the same directory, and committed with `os.replace`.

## Reserved Keys

`schema_version`

: Integer schema version. Albion M2 uses `1`.

`strikes.<operation_key>`

: Integer counter for PostToolUse strike accounting. Operation keys are chosen by hook logic in later packets.

`tasks.open`

: Integer count of open task items used by completion-gate logic.

`last_test`

: Object describing the most recent test command observed by hook logic.

```json
{
  "command": "bash tests/run.sh",
  "status": "pass",
  "at": "2026-07-04T12:00:00Z"
}
```

`notes`

: Hook-readable structured notes. This store is for counters and status, not for secrets or credential material.

## Completion Manifest

When the Stop gate allows a stop with no block reasons, it writes:

```text
${ALBION_MANIFEST_PATH:-$PWD/.albion/completion-manifest.json}
```

The file is JSON, written atomically with a temporary sibling file and replace. The conductor treats file existence as the completion signal. Blocked stops, malformed hook payloads, and hook error paths do not write this file. Manifest write failures are logged to `${ALBION_GATE_LOG:-/dev/null}` and do not change the Stop hook decision.

```json
{
  "schema": "albion-completion-manifest/v1",
  "session_id": "session-id",
  "written_at": "2026-07-04T12:00:00Z",
  "status": "complete",
  "last_test": "pass",
  "workbench_tasks": [{"slug": "task-slug", "verification_present": true}],
  "open_task_count": 0
}
```

`last_test` is `pass`, `fail`, or `unknown`. `workbench_tasks` contains workbench task slugs and whether non-empty verification is present; it never contains task or verification file contents.

## Extension Policy

Unknown top-level keys are permitted and preserved. Hook implementations must not delete or rewrite keys they do not own.
