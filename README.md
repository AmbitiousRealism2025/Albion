# Albion

https://github.com/user-attachments/assets/df653b40-7605-4022-a802-2dd6d136db2c

[![CI](https://github.com/AmbitiousRealism2025/Albion/actions/workflows/ci.yml/badge.svg)](https://github.com/AmbitiousRealism2025/Albion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Run Claude Code on GLM-5.2 — same workflow, a fraction of the model cost, with discipline built in.**

Albion is an MIT-licensed configuration layer that points the Claude Code CLI at
Z.ai's **GLM-5.2** — nothing forked, nothing patched — and wraps the cheaper
model in an operating discipline it needs to be trusted with real work:

- **An always-on operating charter** injected into every session — no modes, no
  trigger phrases. It makes the model keep a plain-file working board
  (`task.md` + `verification.md`) for every non-trivial task.
- **Deterministic enforcement hooks** — a stop gate that blocks "done" until the
  work is verified, a destructive-command guard, a secrets scrubber for the
  working notes, and state re-injection so the board survives context
  compaction.
- **Delegate agents and on-demand skills** — scouts, a fresh-context verifier, a
  counterexample hunter — with per-agent reasoning-effort routing that
  actually reaches the API.
- **A vision helper** (`albion-vision`) so image reads work, and **telemetry**
  that reports your real cost (Claude Code's built-in cost display is wrong
  against non-Anthropic endpoints).

Why people try it: GLM-5.2 coding plans start at **$18/month** with a
**1M-token context**, there is **nothing to migrate**, and Albion runs beside
your stock Claude Code without touching it.

## Install

**From the plugin marketplace** (inside Claude Code):

```
/plugin marketplace add AmbitiousRealism2025/albion-marketplace
/plugin install albion@albion
```

Enabling the plugin puts the `albion` launcher on your PATH; set your Z.ai
credential (`albion-setup` or `export ALBION_ZAI_TOKEN=...`), then run
`albion-doctor --live` and `albion`.

**Or from a fresh clone:**

```bash
./install.sh          # checks prerequisites, puts the tools on your PATH
albion-setup          # (optional) securely stores your Z.ai token
albion-doctor --live  # verifies everything, including a 1-token live probe
albion                # Claude Code on GLM-5.2 + charter + enforcement plugin
```

`install.sh` symlinks `albion`, `albion-doctor`, `albion-vision`, `albion-compile`, and `albion-setup` into `~/.local/bin` (override with `--prefix DIR`) and prints the PATH line to add if needed. It never reads or writes a token. `albion-setup` prompts for your credential with hidden input and writes a mode-600 secrets file. New to running GLM-5.2 in Claude Code? See the [GLM-5.2 setup guide](docs/glm-5.2-setup.md).

Albion also packages into a **single self-contained plugin directory** (`bin/albion-package`) that carries the launcher and everything it needs — the form used for marketplace distribution (see [`docs/packaging.md`](docs/packaging.md)).

## Quickstart (without installing)

Prerequisites: Claude Code ≥ 2.1.163 (2.1.195+ preferred), `bash`, `python3`, `curl`, and a Z.ai credential — a **Coding Plan** subscription token or a metered **API key**.

```bash
git clone https://github.com/AmbitiousRealism2025/Albion.git && cd Albion
export ALBION_ZAI_TOKEN="<your Z.ai token>"   # plan lane is the default
bin/albion-doctor --live
bin/albion
```

| Command | What it does |
|---|---|
| `albion` | GLM-5.2 + the ALBION.md charter + the enforcement plugin |
| `albion --vanilla` | Bare GLM-5.2, no charter or plugin — compare for yourself |
| `albion --doctor` / `albion-doctor --live` | Health matrix; non-zero exit on any red cell |
| `albion-setup` | Interactively store your Z.ai (and optional vision) credentials |
| `albion-vision <image>` | One-shot image description via GLM-4.6V (both auth lanes) |
| `albion-compile --check` | Verifies the charter matches its `manifest/` source fragments |

Auth lanes: `ALBION_AUTH_LANE=plan` (default; prompt-metered) or `api` (token-metered). Plan tokens work **only** on Z.ai's Anthropic-compatible endpoint — Albion routes this correctly and its diagnostics name the notorious `1113` wrong-lane error for what it is. For a metered main model with a separate GLM-4.6V key, set `ALBION_VISION_TOKEN` (and optionally `ALBION_VISION_LANE`). The full list of launcher environment overrides is in the [setup guide](docs/glm-5.2-setup.md).

## Runs alongside stock Claude Code

You can try Albion **without disrupting your normal Claude Code.** Everything Albion changes — the Z.ai endpoint, the model, the charter, the plugin — is set *per invocation* by `bin/albion`; nothing is written to your shell profile or global config. So in one terminal `albion` runs GLM-5.2 with the full operating system, and in another `claude` runs stock Anthropic Claude, with zero interference. Even if you enable the Albion plugin globally from the marketplace, its hooks stay **inert in stock `claude` sessions** — they gate on a marker only the `albion` launcher sets. Albion also scopes its `xhigh` (GLM-max) effort to its own sessions, so it never changes how your stock Claude reasons.

## What's inside

1. **`charter/ALBION.md` — the operating document (always-on).** One
   non-negotiable rule: every task above trivial opens a working board with a
   definition of done and an evidence-backed verification record. Deep-analysis
   discipline (state maps, competing hypotheses, counterexample-first recovery)
   engages by escalation when a problem resists. Compiled from
   `manifest/sections/` by `bin/albion-compile`, with a byte-exact drift gate.
2. **On-demand skills & agents** (`plugin/`) — skills for delegation, recovery,
   and completion; agents `scout`, `counterexample-hunter`, `verifier`,
   `simplifier`, `quick`, each with wire-verified per-agent effort routing.
3. **Hook enforcement suite** (`plugin/hooks`, `plugin/scripts`) —
   destructive-command guard, strike counter, workbench secrets scrubber,
   Stop-gate completion enforcement, post-compaction state re-injection, and
   image-read interception. Every hook ships with recorded-payload tests plus a
   live registration smoke-check; what hooks can and cannot defend is stated
   honestly in [`docs/security-model.md`](docs/security-model.md).
4. **Launcher + vision** (`bin/`) — Z.ai endpoint pinning, both auth lanes,
   `glm-5.2[1m]` model slots, cache hygiene, loud startup validation; vision is
   pluggable, with direct GLM-4.6V over HTTP as the default (no MCP
   dependency).

For orchestrating fleets — a frontier-model session conducting GLM-backed
Albion workers over tmux — there is a documented conductor protocol and skill;
Albion never *requires* it. See [`docs/build/orchestration.md`](docs/build/orchestration.md).

## What to expect (measured, not promised)

Albion's benchmarks are public and honest about what the layer does and does
not change:

- At maximum reasoning effort, GLM-5.2 **solves the bench tasks with or
  without** the charter. Albion does not claim "solves more."
- What the charter buys is **process you can trust**: an auditable working
  board with a verification record, and recovery of the task state across
  context resets — behaviors measured in controlled A/Bs, not asserted.
- Real cost: a medium orchestrated task lands around **$1.20 on the API lane**
  (warm cache), or **≈3 prompt-equivalents** on a Coding Plan whose $18/mo tier
  covers 9–25 such tasks per 5-hour window.

The full evidence trail, methodology, and experiment logs are in the
[development record](docs/build/README.md).

## What's next

Provider abstraction (a data-sovereignty toggle for US-resident hosts of the
MIT open weights, or self-hosting), interactive conductor steering, and
marketplace distribution. Further out: ports of the same manifest and
conductor protocol to other coding CLIs.

## Built in the open

Albion was built by the pattern it ships — a frontier-model conductor
dispatching reviewable work packets to a second AI over tmux, with mechanical
acceptance gates before every merge — and the journal of that build is public,
including the failures. The methodology, milestone trail, build logs, and
empirical findings live in the [development record](docs/build/README.md).

## Contributing & security

Contributions are welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md) for the test suite, portability rules, and how changes are reviewed. Security reports: [`SECURITY.md`](SECURITY.md); the honest threat model is [`docs/security-model.md`](docs/security-model.md).

## Disclosures

- Z.ai first-party serving routes prompts/code through servers in China; the roadmap includes a provider-abstraction toggle (US-resident hosts of the MIT open weights, or self-hosting) with documented quantization-quality caveats.
- Claude Code's built-in cost display is incorrect against non-Anthropic endpoints; Albion's telemetry is the source of truth.
- Vision-model behavior on the plan lane relies on an entitlement Z.ai's documentation does not list; the doctor's live probe is the tripwire if it changes.

## License

[MIT](LICENSE)
