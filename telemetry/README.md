# Albion Telemetry

`telemetry/albion-metrics` converts one headless `bin/albion --output-format json`
result plus best-effort Albion session state into one JSON record.

```bash
telemetry/albion-metrics --result headless-result.json [--lane plan|api] \
  [--session <id>] [--state-dir <dir>] [--task-label <text>] [--pretty]
```

Default lane is `${ALBION_AUTH_LANE:-plan}`. Default session is the result
file's `session_id`. Default state dir is `${ALBION_STATE_DIR:-.albion/state}`.
Missing state is not an error; state-backed fields become `null`.

## Record Schema

Schema string: `albion-task-metrics/v1`.

Fields:

- `task_label`: optional label from `--task-label`.
- `session_id`: `--session`, else result `session_id`.
- `lane`: `plan` or `api`.
- `duration_ms`, `num_turns`: passthrough from the result.
- `usage.models`: per `modelUsage` slug token counts:
  `input_tokens`, `output_tokens`, `cache_read_input_tokens`,
  `cache_creation_input_tokens`.
- `usage.totals`: summed raw token counts for downstream re-pricing.
- `model_calls.turns`: `num_turns`, used as the documented call-count proxy.
- `cost`: lane-specific cost object.
- `harness_reported_cost_usd`: untrusted passthrough of result `total_cost_usd`.
- `strikes`: max integer value under state `strikes`, or `null`.
- `gate_blocks`: state `gate.blocks`, or `null`.
- `last_test`: state `last_test` object, or `null`.
- `workbench_present`: true when `${ALBION_WORKBENCH_ROOT:-$PWD/.agent-workbench}/fable-mode`
  contains any task directories.
- `is_error`, `terminal_reason`: passthrough from the result.

The tool ignores Claude Code `total_cost_usd` and per-model `costUSD` for
computed cost because they are wrong under Z.ai; the harness value is included
only for comparison.

## Cost Model

API lane costs are computed from `modelUsage` tokens after stripping a trailing
model suffix such as `[1m]`. Cache-creation input tokens are billed as input.

Price table, USD per million tokens:

| Model | Input | Cache read | Output |
|---|---:|---:|---:|
| `glm-5.2` | 1.40 | 0.26 | 4.40 |
| `glm-4.6v` | 0.30 | 0.05 | 0.90 |
| `glm-5-turbo` | null | null | null |

Unknown models or models with `null` prices emit `cost.usd: null` and
`cost.pricing_incomplete: true`; no price is guessed.

Plan lane reports prompt-equivalents instead of dollars:

```text
prompt_equivalents = (model_calls.turns / 18) * ALBION_PEAK_MULTIPLIER
```

`ALBION_PEAK_MULTIPLIER` defaults to `1`. Operators set it for peak windows;
the tool does not compute wall-clock timezones.
