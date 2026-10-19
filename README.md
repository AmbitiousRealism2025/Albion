# Albion

https://github.com/user-attachments/assets/df653b40-7605-4022-a802-2dd6d136db2c

[![CI](https://github.com/AmbitiousRealism2025/Albion/actions/workflows/ci.yml/badge.svg)](https://github.com/AmbitiousRealism2025/Albion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Run Claude Code on Z.ai's GLM-5.3 with a working board, completion checks,
specialist agents, vision, and cost telemetry.

Albion is an MIT-licensed launcher and Claude Code plugin. It points the stock
Claude Code CLI at Z.ai's Anthropic-compatible API, then adds an operating
charter and a set of hooks. It does not fork or patch Claude Code.

The goal is narrower than making the model smarter. Albion tries to make long
coding sessions easier to inspect and harder to abandon half-finished. Every
non-trivial task gets a plain-file board with its deliverables and verification
record. Hooks preserve that state across compaction and can block completion
when the recorded work is still open.

## Why Albion exists

GLM-5.3 has open weights, selectable reasoning effort, and a 1 million token
context window. Z.ai also offers it through GLM Coding Plan. Those properties
make it useful for long coding tasks, but a large context window does not keep
an agent honest or organized by itself.

Albion's own benchmark results make a modest claim:

- At maximum reasoning effort, GLM-5.2 solved the current tasks with and
  without Albion.
- Albion changed the work record. Sessions created task boards, recorded
  verification, and recovered that state after context resets more reliably.
- The added verification took time. In the v0.3 validation batch, Albion's
  runs were about 17 percent longer.

Read the [development record](docs/build/README.md) for the experiments,
failures, and small-sample limits behind those statements.

## Install

You need Claude Code 2.1.163 or newer, plus `bash`, `python3`, `curl`, and a Z.ai
credential. Claude Code 2.1.195 or newer is preferred.

### Plugin marketplace

Run these commands inside Claude Code:

```text
/plugin marketplace add AmbitiousRealism2025/albion-marketplace
/plugin install albion@albion
```

Then configure your credential and check the installation:

```bash
albion-setup
albion-doctor --live
albion
```

`albion-setup` reads the token without echoing it and writes a mode `600`
secrets file.

### Clone and install

```bash
git clone https://github.com/AmbitiousRealism2025/Albion.git
cd Albion
./install.sh
albion-setup
albion-doctor --live
albion
```

The installer adds symlinks under `~/.local/bin` by default. Pass
`--prefix DIR` to use another directory. It does not read or write credentials.

To try Albion without installing it:

```bash
export ALBION_ZAI_TOKEN="<your Z.ai token>"
bin/albion-doctor --live
bin/albion
```

See the [GLM-5.3 setup guide](docs/glm-5.3-setup.md) for authentication lanes,
environment overrides, and a manual Claude Code configuration.

## What runs in an Albion session

The `albion` launcher changes one process. It does not write the Z.ai endpoint,
model mapping, charter, or effort level to your global Claude Code settings.

For each invocation, the launcher:

1. Selects the Z.ai endpoint and credential for the chosen authentication lane.
2. Maps Claude Code's model slots to GLM models.
3. Appends [`charter/ALBION.md`](charter/ALBION.md) to the system prompt.
4. Loads the plugin and its permissions settings, which start the session in
   auto mode so unattended runs don't stop for approvals.
5. Starts the stock `claude` binary.

The plugin adds four groups of behavior:

- The working board stores `task.md` and `verification.md` under
  `.agent-workbench/fable-mode/`.
- Hooks guard named destructive commands, redact recognized credentials from
  board files, count failed tool use, restore state after compaction, and check
  completion state when the session stops.
- Five agents cover scouting, quick bounded work, counterexample search,
  simplification, and verification. Skills load the longer procedures only
  when the task calls for them.
- `albion-vision` sends image requests to GLM-5.3-Flash. `albion-metrics` calculates
  cost from Z.ai usage rather than Claude Code's Anthropic price table.

The hooks activate only when the launcher sets `ALBION_ACTIVE=1`. A stock
`claude` session does not set that marker, even when the plugin is installed.
Use `albion --vanilla` to run the same GLM configuration without the charter or
plugin.

## Commands

| Command | Purpose |
|---|---|
| `albion` | Start GLM-5.3-Flash (default) with the charter, plugin, and Albion settings; GLM-5.3 sits in the opus slot |
| `albion --vanilla` | Start the same GLM configuration without the charter or plugin |
| `albion --dry-run` | Print the resolved configuration with the token masked |
| `albion-doctor --live` | Check the local setup and make a one-token API probe |
| `albion-setup` | Store the main and optional vision credentials |
| `albion-vision <image>` | Describe an image with GLM-5.3-Flash |
| `albion-compile --check` | Check the compiled charter against `manifest/sections/` |
| `albion-package` | Build a self-contained plugin directory under `dist/albion` |
| `bin/albion-t3-code` | T3 Code provider launcher; loads local Albion secrets, then runs `bin/albion` |

For a T3 Code provider instance, use `bin/albion-t3-code` as the binary path and
add the model IDs `glm-5.3-flash[1m]` and `glm-5.3[1m]` to the provider's model list.

## Authentication

Albion supports two Z.ai billing paths:

| Lane | Credential | Metering | Default endpoint |
|---|---|---|---|
| `plan` | GLM Coding Plan token | Provider plan quota | `https://api.z.ai/api/anthropic` |
| `api` | Metered API key | Input and output tokens | `https://api.z.ai/api/anthropic` |

Set `ALBION_AUTH_LANE=plan` or `ALBION_AUTH_LANE=api`. The lane-specific token
variables are `ALBION_ZAI_PLAN_TOKEN` and `ALBION_ZAI_API_KEY`.
`ALBION_ZAI_TOKEN` is the fallback for either lane.

Z.ai currently lists Coding Plan subscriptions from $18 per month. Provider
prices and quotas can change, so check [Z.ai's current documentation](https://docs.z.ai/guides/overview/quick-start)
before making a cost decision.

## What the safety checks do

Albion is not a sandbox.

Claude Code's permissions deny rules form the hard floor for a short list of
literal dangerous operations and credential paths. Albion's shell guard,
secrets scrubber, and stop gate add checks above that floor. They are meant to
catch mistakes and model drift, not a determined process with arbitrary shell
access.

Important limits:

- The command guard cannot recognize every runtime indirection or destructive
  operation. Parser failures allow the command and write a log entry.
- The scrubber runs after a board file is written and recognizes a finite list
  of credential formats.
- The stop gate reads agent-writable state. It checks for missing evidence and
  open work, but it cannot judge whether the evidence is good or prevent state
  tampering.

Read the [security model](docs/security-model.md) before using Albion on
sensitive work. Report security problems through the process in
[`SECURITY.md`](SECURITY.md).

## Evidence and project history

Albion keeps its build record in the repository. Start with:

- [Development record](docs/build/README.md), the project history and current
  roadmap.
- [Field-tuning report](docs/build/log/023-field-tuning-round.md), the v0.3
  validation batch and its limits.
- [Benchmark documentation](bench/README.md), the task runner and record
  format.
- [First A/B report](bench/reports/m5-first-ab-report.md), the original small
  comparison between Albion and vanilla GLM-5.2.
- [Conductor protocol](docs/build/orchestration.md), the optional tmux workflow
  used during development.

The repository also records an important failure. The hook configuration had
the expected schema but did not load in live Claude Code sessions. An exit test
found the problem, and the suite now includes a registration smoke test for
that class of failure.

## Data handling and unstable dependencies

- Z.ai's first-party service processes prompts and code on infrastructure in
  China. Do not send material that your policy forbids the provider from
  receiving.
- Albion depends on Claude Code's plugin schema, hook payloads, command-line
  flags, and environment behavior. `albion-doctor` and the test suite detect
  known breakage, but an upstream Claude Code release can still require an
  Albion update.
- Direct GLM-5.3-Flash vision use with a Coding Plan token was established by live tests,
  not provider documentation. `albion-doctor --live` checks that path before
  you rely on it.

## Contributing

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`CONVENTIONS.md`](CONVENTIONS.md)
before changing code. Charter edits belong in `manifest/sections/`, not directly
in the compiled `charter/ALBION.md` file.

The [documentation index](docs/README.md) links the user, contributor, security,
benchmark, and build records.

## License

[MIT](LICENSE)
