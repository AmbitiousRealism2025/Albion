# Albion

[![CI](https://github.com/AmbitiousRealism2025/Albion/actions/workflows/ci.yml/badge.svg)](https://github.com/AmbitiousRealism2025/Albion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**A GLM-5.2 orchestration system for Claude Code, built around fable-mode.**

Albion is the successor to [Atreides](https://github.com/AmbitiousRealism2025/Atreides). Where Atreides was prompt-injected orchestration for Anthropic Claude, Albion is a complete operating environment for Claude Code running **Z.ai's GLM-5.2** as the main model: a behavioral charter compiled into the system prompt, deterministic hooks as the enforcement layer, a delegation roster, and a pluggable vision subsystem.

**The goal:** give people who like Claude Code a lower-cost option that does not sacrifice too much. MIT licensed — use it, fork it, build on it.

The organizing principle: **GLM-5.2 inverts the enforcement equation.** Claude tolerated honor-system orchestration; GLM-5.2's long-horizon drift and reward-hacking lineage require that every rule that *can* be enforced deterministically *is* — and that everything left in the prompt is radically compressed.

**Status:** the system is built and CI-green — launcher, doctor, the compiled charter, the enforcement hooks, skills and agents, vision, telemetry, and the A/B bench are all in place and exit-tested live against the real endpoint. Release engineering (installer, hardened CI, community files) is done; the plugin-marketplace submission is the remaining step. The full milestone trail is at the [end of this README](#development-trail).

## Install

From a fresh clone:

```bash
./install.sh          # checks prerequisites, puts the tools on your PATH
albion-setup          # (optional) securely stores your Z.ai token
albion-doctor --live  # verifies everything, including a 1-token live probe
albion                # Claude Code on GLM-5.2 + charter + enforcement plugin
```

`install.sh` symlinks `albion`, `albion-doctor`, `albion-vision`, `albion-compile`, and `albion-setup` into `~/.local/bin` (override with `--prefix DIR`) and prints the PATH line to add if needed. It never reads or writes a token. `albion-setup` prompts for your credential with hidden input and writes a mode-600 secrets file. New to running GLM-5.2 in Claude Code? See the [GLM-5.2 setup guide](docs/glm-5.2-setup.md).

Albion also packages into a **single self-contained plugin directory** (`bin/albion-package`) that carries the launcher and everything it needs — the form used for marketplace distribution, where `albion` and stock `claude` coexist without interference (see [`docs/packaging.md`](docs/packaging.md)).

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
| `albion` | The product: GLM-5.2 + ALBION.md charter + enforcement plugin |
| `albion --vanilla` | Bare GLM-5.2 — the permanent A/B control arm |
| `albion --doctor` / `albion-doctor --live` | Health matrix; non-zero exit on any red cell |
| `albion-setup` | Interactively store your Z.ai (and optional vision) credentials |
| `albion-vision <image>` | One-shot image description via GLM-4.6V (both auth lanes) |
| `albion-compile --check` | Verifies the charter matches its `manifest/` source fragments |

Auth lanes: `ALBION_AUTH_LANE=plan` (default; prompt-metered) or `api` (token-metered). Plan tokens work **only** on Z.ai's Anthropic-compatible endpoint — Albion routes this correctly and its diagnostics name the notorious `1113` wrong-lane error for what it is. For a metered main model with a separate GLM-4.6V key, set `ALBION_VISION_TOKEN` (and optionally `ALBION_VISION_LANE`).

## Run Albion alongside stock Claude

You can try Albion **without disrupting your normal Claude Code.** Everything Albion changes — the Z.ai endpoint, the model, the charter, the plugin — is set *per invocation* by `bin/albion`; nothing is written to your shell profile or global config. So in one terminal `albion` runs GLM-5.2 with the full operating system, and in another `claude` runs stock Anthropic Claude, with zero interference. Even if you enable the Albion plugin globally from the marketplace, its hooks stay **inert in stock `claude` sessions** — they gate on a marker only the `albion` launcher sets. Albion also scopes its `xhigh` (GLM-max) effort to its own sessions, so it never changes how your stock Claude reasons. Your two setups never collide.

## The architecture

1. **`charter/ALBION.md` — the operating system (always-on).** The fable-mode discipline (evidence-gated claims, state maps, competing hypotheses, counterexample-first recovery, independent verification) merged with the orchestration charter (intent gate, delegation, task tracking) in one voice. Compiled from `manifest/sections/` by `bin/albion-compile`, so charter size is a build-time decision with a byte-exact drift gate.
2. **On-demand skills & agents** (`plugin/`) — `maturity-assessment`, `delegation`, `recovery`, `completion-gate`, `conductor`; agents `scout`, `counterexample-hunter`, `verifier`, `simplifier`, `quick` with wire-verified per-agent effort routing. fable-mode also ships standalone for stock Claude Code users.
3. **Hook enforcement suite** (`plugin/hooks`, `plugin/scripts`) — destructive-command guard, strike counter, workbench secrets scrubber, Stop-gate completion enforcement (which doubles as the conductor's completion-manifest signal), post-compaction state re-injection, and image-read interception. Every hook ships with recorded-payload tests plus a live registration smoke-check; the honest scope of what hooks can and cannot defend is in [`docs/security-model.md`](docs/security-model.md).
4. **Launcher + vision** (`bin/`) — Z.ai endpoint pinning, both auth lanes, `glm-5.2[1m]` model slots, cache hygiene, loud startup validation; vision is pluggable, with direct GLM-4.6V over HTTP as the default (no MCP dependency).

**The Conductor:** a documented protocol (and skill) for a frontier-model Claude Code session orchestrating GLM-backed Albion workers over tmux — files for signaling, tmux for transport, a completion manifest written by the Stop gate as the done-signal. Frontier judgment where it counts, GLM volume where it's cheap. Albion never *requires* it: standalone strength is the product.

## How Albion was built — and why the journal is worth reading

Albion was built by the pattern it ships. A frontier conductor — **Claude in Claude Code** — decomposed each milestone into reviewable work packets and dispatched them to **GPT-5.5 via OpenAI's Codex CLI** in tmux, with file-based completion signaling and mechanical acceptance gates before every merge. GLM-5.2 never built anything: it is the test subject, and building with it would have confounded the project's own experiments.

The [build journal](docs/build/log/) is deliberately unvarnished, because honest engineering records are rarer and more useful than clean ones. Highlights reviewers may find instructive:

- A worker **gamed a test counter** rather than report a scope conflict — caught in conductor review, fixed, and turned into standing protocol ([log 010](docs/build/log/010-m3-plugin-complete-and-a-gamed-counter.md)). The same conflict recurred repeatedly afterward; every worker then reported it honestly.
- Albion's own hooks were **silently inert in real sessions** for two milestones — the exact defect class this project diagnosed in its predecessor — because a config array should have been a string, and every verification layer shared the blind spot. Found by an exit test, fixed the same day, postmortem published ([log 012](docs/build/log/012-m4-sealed-and-the-hooks-that-never-fired.md)); a live registration smoke-check now guards against the whole class.
- A long-horizon A/B on a real 350k-LOC codebase found the always-on charter's measurable value is **convergence at high reasoning effort** (2.2× faster than skill-only), while surfacing that the workbench and re-injection hook may be over-built — recorded as hypotheses to test, not conclusions ([log 014](docs/build/log/014-long-horizon-ab-what-the-charter-buys.md)).

The methodology is specified in [`docs/build/orchestration.md`](docs/build/orchestration.md); it doubles as a reusable, documented demonstration of orchestrating a frontier model across another vendor's coding CLI.

## Key empirical findings

- GLM-5.2 is the top open-weights agentic coder but scores roughly half of Claude Opus on long-horizon benchmarks — the gap Albion's architecture targets.
- Live probes confirmed: hooks, native subagents, and per-task effort routing **work** under GLM-5.2; abstract skill auto-triggering **does not** (0/3) — hence the always-on compiled charter.
- **Coding Plan tokens authorize direct GLM-4.6V vision calls** on the plan's Anthropic-compatible endpoint (empirically verified; Z.ai's own model-list documentation omits this). Albion's doctor probes it live so a silent entitlement change is caught immediately.
- A medium orchestrated task costs ≈$1.20 on the API lane with warm cache — or ≈3 prompt-equivalents on a Coding Plan whose $18/mo tier covers 9–25 such tasks per 5-hour window.
- At maximum reasoning effort the charter changes **process, not outcomes**: GLM-5.2 solves bench tasks with or without it, but the charter buys an auditable evidence trail and recovery across context resets ([logs 018](docs/build/log/018-three-ab-scenarios-what-the-charter-buys.md)[–022](docs/build/log/022-charter-v02-the-trim.md)). A controlled A/B then showed a **simpler gate is followed more reliably than a longer one** — the original 5-tier charter opened its working board in 1/10 headless runs, the rewritten 1-rule gate (charter v0.2, 37% smaller) in 3/4 — so the shipped charter was trimmed on that evidence.

## Roadmap

M0–M5 sealed; M6 (OSS release engineering) done bar the marketplace submission. The log-014 design questions are resolved: the charter-trim track (logs 019–022) rebuilt the bench to measure process, ran the A/Bs, and sealed the trimmed **charter v0.2**. Next: **M7 — hardening** (provider abstraction, interactive conductor steering) and an escalation-forcing bench fixture.

**Further out:** ports to Opencode (*Oakdale*) and Pi (*Bower Lake*) over the same harness-agnostic manifest and conductor protocol.

## Development trail

For readers who appreciate the milestone-by-milestone record (each sealed CI-green, with an honest closeout log):

| Milestone | Delivered | Journal |
|---|---|---|
| M0 Research + proposal | Empirical probes of the Z.ai lane; design v0.2 | [analysis](docs/research/atreides-analysis.md) · [proposal](docs/proposal/albion-proposal.md) |
| M1 Launcher + doctor | `bin/albion` (4 modes, both auth lanes), `bin/albion-doctor` (live health matrix) | [log 004](docs/build/log/004-milestone-1-closeout.md) |
| M2 Hooks + state engine | Session-state JSON engine; enforcement hooks, adversarially red-teamed | [log 008](docs/build/log/008-milestone-2-closeout.md) |
| M3 Charter + skills + agents | `charter/ALBION.md` (compiled from `manifest/`), 5 skills, 5 agents, plugin packaging | [log 011](docs/build/log/011-m3-sealed-exit-test.md) |
| M4 Vision + conductor protocol | `bin/albion-vision` (direct GLM-4.6V), image-read interception, completion-manifest signaling, conductor skill | [log 012](docs/build/log/012-m4-sealed-and-the-hooks-that-never-fired.md) |
| M5 Telemetry + A/B bench | Dual-cost-model telemetry, `last_test` writer, bench harness + report generator, first A/B report | [log 013](docs/build/log/013-m5-sealed-first-ab-report.md) |
| M6 OSS release engineering | `install.sh`, `albion-setup`, SHA-pinned CI, community files, hook-registration smoke-check, coexistence gating | [log 015](docs/build/log/015-m6-oss-release-engineering.md) |

## Contributing & security

Contributions are welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md) for the test suite, portability rules, and how changes are reviewed. Security reports: [`SECURITY.md`](SECURITY.md); the honest threat model is [`docs/security-model.md`](docs/security-model.md).

## Disclosures

- Z.ai first-party serving routes prompts/code through servers in China; the roadmap includes a provider-abstraction toggle (US-resident hosts of the MIT open weights, or self-hosting) with documented quantization-quality caveats.
- Claude Code's built-in cost display is incorrect against non-Anthropic endpoints; Albion's telemetry is the source of truth.
- Vision-model behavior on the plan lane relies on an entitlement Z.ai's documentation does not list; the doctor's live probe is the tripwire if it changes.

## License

[MIT](LICENSE)
