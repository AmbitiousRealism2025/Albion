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

## Extension Policy

Unknown top-level keys are permitted and preserved. Hook implementations must not delete or rewrite keys they do not own.
