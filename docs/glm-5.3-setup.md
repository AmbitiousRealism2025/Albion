# Run Claude Code on GLM-5.3

Albion runs the stock Claude Code CLI against Z.ai's GLM-5.3 API. It does not
patch the CLI. The launcher sets the API endpoint, credential, model mapping,
charter, plugin, and Albion settings for one process.

This guide covers the normal Albion setup and the equivalent manual Claude Code
configuration.

## Requirements

- Claude Code 2.1.163 or newer. Version 2.1.195 or newer is preferred.
- `bash`, `curl`, and `python3`.
- A Z.ai GLM Coding Plan token or a metered Z.ai API key.

Z.ai documents the Anthropic Messages endpoint for Claude Code at
`https://api.z.ai/api/anthropic`. See the provider's
[tool integration guide](https://docs.z.ai/devpack/tool/others) for its current
endpoint and plan restrictions.

## Configure Albion

The interactive setup is the simplest path:

```bash
albion-setup
albion-doctor --live
albion
```

`albion-setup` asks which authentication lane to use, reads the credential
without echoing it, and writes a mode `600` secrets file. The doctor checks the
local files, Claude Code version, endpoint, effort setting, hook registration,
and API access.

For a temporary session, export a token instead:

```bash
export ALBION_ZAI_TOKEN="<your Z.ai token>"
export ALBION_AUTH_LANE="plan"
bin/albion-doctor --live
bin/albion
```

## Authentication lanes

Albion supports two billing paths:

| Lane | Preferred variable | Metering | Endpoint |
|---|---|---|---|
| `plan` | `ALBION_ZAI_PLAN_TOKEN` | GLM Coding Plan quota | `https://api.z.ai/api/anthropic` |
| `api` | `ALBION_ZAI_API_KEY` | API tokens | `https://api.z.ai/api/anthropic` |

`ALBION_ZAI_TOKEN` is the fallback when the lane-specific variable is unset.
The plan lane is the default.

Use the Anthropic endpoint with Claude Code. A Coding Plan token sent to the
general OpenAI-compatible endpoint can return error `1113`, which usually means
the credential and endpoint belong to different billing paths.

## Manual Claude Code configuration

You can run GLM-5.3 without the Albion charter or plugin. Set the environment
that Albion normally owns:

```bash
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="<your Z.ai token>"

export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.3[1m]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.3-flash"
# Leave ANTHROPIC_DEFAULT_SONNET_MODEL unset so Claude Code's auto-mode
# permission classifier keeps its fast default (see env/albion-env.sh).

claude --model 'glm-5.3-flash[1m]'   # or 'glm-5.3[1m]' for heavier reasoning
```

The `[1m]` suffix selects the 1 million token context variant. Z.ai describes
that context window in its [GLM-5.3 release note](https://z.ai/blog/glm-5.3).

Do not set `CLAUDE_CODE_EFFORT_LEVEL` for Albion. Claude Code treats it as a
global override, which prevents Albion's agents and skills from selecting their
own effort. Albion passes a session settings file with `effortLevel` set to
`xhigh` instead.

## Launcher overrides

`bin/albion` reads these variables before starting Claude Code:

| Variable | Effect |
|---|---|
| `ALBION_AUTH_LANE` | Select `plan` or `api` |
| `ALBION_ZAI_PLAN_TOKEN` | Credential for the plan lane |
| `ALBION_ZAI_API_KEY` | Credential for the API lane |
| `ALBION_ZAI_TOKEN` | Fallback credential for either lane |
| `ALBION_MODEL` | Model passed to `claude --model`; defaults to `glm-5.3-flash[1m]` |
| `ALBION_CHARTER` | Alternate charter path, used by A/B experiments |
| `ALBION_ALLOW_OVERRIDES` | Preserve existing Claude Code model mappings when set to `1` |
| `ALBION_VISION_TOKEN` | Separate credential for vision (GLM-5.3-Flash) |
| `ALBION_VISION_LANE` | Billing lane for the separate vision credential |

The header in [`env/albion-env.sh`](../env/albion-env.sh) documents the tuning
variables for timeouts, compaction, output limits, and subprocess behavior.

Run `albion --dry-run` to inspect the resolved lane, models, charter path, and
Claude Code arguments. The output masks the credential.

## Vision

`albion-vision` sends image requests directly to GLM-5.3-Flash. A separate vision
credential is useful when the main model uses the API lane but vision should
use a different account or billing path.

```bash
export ALBION_VISION_TOKEN="<vision credential>"
export ALBION_VISION_LANE="api"
albion-vision screenshot.png
```

Coding Plan access to direct GLM-5.3-Flash vision calls came from Albion's live tests, not a
documented provider guarantee. `albion-doctor --live` probes that path so an
entitlement change fails before an image task depends on it.

## Cost reporting

Claude Code calculates its built-in dollar total with Anthropic prices. That
number does not represent a Z.ai request. `telemetry/albion-metrics` reads the
reported token counts and applies Albion's Z.ai price table for the API lane.
For the plan lane, it reports prompt equivalents instead of dollars.

Price tables age. Check [`telemetry/README.md`](../telemetry/README.md) and the
provider's current pricing before using the result for budgeting.

## Coexistence with stock Claude Code

The launcher exports its endpoint and model settings only to the process it
starts. It does not update your shell profile or global Claude Code config.

The plugin hooks also check `ALBION_ACTIVE=1`. Only the Albion launcher sets
that marker while loading the plugin. This keeps a globally installed Albion
plugin inert in an ordinary `claude` session.

You can therefore run these in separate terminals:

```text
albion    GLM-5.3-Flash with the Albion charter and plugin
claude    your normal Claude Code configuration
```

## Troubleshooting

Start with:

```bash
albion-doctor --live
```

Common failures:

| Symptom | Likely cause | Check |
|---|---|---|
| Error `1113` | Coding Plan token sent to the wrong endpoint | Lane and `ANTHROPIC_BASE_URL` |
| Claude model name reaches Z.ai | Model mapping or `--model` pin is missing | `albion --dry-run` |
| Per-agent effort does not change | `CLAUDE_CODE_EFFORT_LEVEL` is set globally | Unset it before launch |
| Hooks do not fire | Plugin did not register or `ALBION_ACTIVE` is absent | Doctor registration check |
| Vision fails while text works | Vision credential or entitlement differs | Doctor's live vision probe |

If the doctor reports a hook or schema failure after a Claude Code upgrade,
open an issue with the Claude Code version, Albion version, doctor output, and
the smallest reproduction that does not expose a credential.
