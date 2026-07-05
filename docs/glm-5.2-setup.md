# Running Claude Code on GLM-5.2

This guide explains how to run **stock Claude Code against Z.ai's GLM-5.2** instead of
Anthropic's models. There is no fork and no patched binary — it is the normal Claude
Code CLI, pointed at a different endpoint with a few environment variables. Albion
automates everything here (`bin/albion`), but the mechanics are worth understanding,
and they work on their own if you just want cheap GLM-5.2 in Claude Code without the
rest of Albion.

## The idea in one paragraph

Claude Code talks to an Anthropic-compatible API. Z.ai exposes exactly such an API for
its GLM models. So you set `ANTHROPIC_BASE_URL` to Z.ai's endpoint, provide a Z.ai
token, and map Claude Code's model "slots" to GLM model names. Claude Code is none the
wiser — it sends the same requests; they just land at Z.ai and are served by GLM-5.2.

## Prerequisites

- Claude Code ≥ 2.1.163 (2.1.195+ preferred).
- A Z.ai credential: a **Coding Plan** subscription token (prompt-metered) or a metered
  **API key**.
- `bash`, `curl`, `python3`.

## The environment

```bash
# Z.ai's Anthropic-compatible endpoint. NOT /api/paas/v4 — that is the OpenAI-style
# endpoint and a Coding Plan token is rejected there (error 1113).
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="<your Z.ai token>"

# Map Claude Code's model slots to GLM. The [1m] suffix unlocks the 1M-token context.
export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2[1m]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5-turbo"   # the genuinely cheaper tier
```

Then launch Claude Code as usual, pinning the model so Claude Code doesn't try to reach
Anthropic with a Claude model name:

```bash
claude --model 'glm-5.2[1m]'
```

## Gotchas (learned the hard way — see `docs/build/`)

- **Use `/api/anthropic`, never `/api/paas/v4`.** A Coding Plan token on the paas/v4
  endpoint returns `error 1113` ("insufficient balance") regardless of your plan.
- **Keep the `[1m]` suffix** on the model name or you lose the 1M-token context window.
- **Never set `CLAUDE_CODE_EFFORT_LEVEL`.** It is a global override that disables
  per-task/per-subagent effort routing. Set the session default in `settings.json`
  (`"effortLevel": "xhigh"` → GLM's `reasoning_effort: max`, Z.ai's recommendation for
  coding) instead.
- **Ignore Claude Code's cost display.** Its `total_cost_usd` is wrong against a
  non-Anthropic endpoint (it over-reports; Albion's telemetry measures the real cost).

## Auth lanes

| | Coding Plan | API key |
|---|---|---|
| Metering | Prompts per 5-hour window | Tokens (funded balance) |
| Best for | Daily driver | Overflow, CI, bursty fan-out |
| Endpoint | `/api/anthropic` | `/api/anthropic` or `/api/paas/v4` |

Vision (GLM-4.6V) works on the plan token directly via `/api/anthropic`; on a metered
key you can point it at a separate vision credential (see `ALBION_VISION_TOKEN`).

## What Albion adds on top

You can stop here and have cheap GLM-5.2 in Claude Code. Albion wraps all of the above
in one command and adds the operating system around it:

- `bin/albion` sources this environment, pins the model, and injects the charter +
  enforcement plugin — so you just run `albion`.
- `bin/albion-setup` writes your token to a mode-600 secrets file interactively.
- `bin/albion-doctor` verifies every one of these settings (endpoint shape, version,
  effort, a live 1-token probe) and fails loudly on any misconfiguration.
- The enforcement hooks, the compiled charter, vision, telemetry, and the bench are all
  layered on — see the [README](../README.md).

## Coexistence with stock Claude

Everything above is set **per invocation** by `bin/albion` — none of it is written to
your shell profile or global config. So `albion` (GLM) and `claude` (Anthropic) run
side by side in separate terminals with zero interference. See the README's
"Run Albion alongside stock Claude" section.
