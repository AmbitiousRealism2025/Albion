# Albion

[![CI](https://github.com/AmbitiousRealism2025/Albion/actions/workflows/ci.yml/badge.svg)](https://github.com/AmbitiousRealism2025/Albion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**A GLM-5.2 orchestration system for Claude Code, built around fable-mode.**

Albion is the successor to [Atreides](https://github.com/AmbitiousRealism2025/Atreides). Where Atreides was prompt-injected orchestration for Anthropic Claude, Albion is a complete operating environment for Claude Code running **Z.ai's GLM-5.2** as the main model: a behavioral charter compiled into the system prompt, deterministic hooks as the enforcement layer, a delegation roster, and a pluggable vision subsystem.

**The goal:** give people who like Claude Code a lower-cost option that does not sacrifice too much. MIT licensed — use it, fork it, build on it.

The organizing principle: **GLM-5.2 inverts the enforcement equation.** Claude tolerated honor-system orchestration; GLM-5.2's long-horizon drift and reward-hacking lineage require that every rule that *can* be enforced deterministically *is* — and that everything left in the prompt is radically compressed.

## Status

**Milestones M0–M4 are sealed** (verified, CI-green, exit-tested live against the real endpoint). Current work: **M5 — telemetry + the three-arm A/B bench.**

| Milestone | Delivered | Journal |
|---|---|---|
| M0 Research + proposal | Empirical probes of the Z.ai lane; design v0.2 | [analysis](docs/research/atreides-analysis.md) · [proposal](docs/proposal/albion-proposal.md) |
| M1 Launcher + doctor | `bin/albion` (4 modes, both auth lanes), `bin/albion-doctor` (live health matrix) | [log 004](docs/build/log/004-milestone-1-closeout.md) |
| M2 Hooks + state engine | Session-state JSON engine; enforcement hooks, adversarially red-teamed | [log 008](docs/build/log/008-milestone-2-closeout.md) |
| M3 Charter + skills + agents | `charter/ALBION.md` (compiled from `manifest/`), 5 skills, 5 agents, plugin packaging | [log 011](docs/build/log/011-m3-sealed-exit-test.md) |
| M4 Vision + conductor protocol | `bin/albion-vision` (direct GLM-4.6V, both lanes), image-read interception, completion-manifest signaling, conductor skill | [log 012](docs/build/log/012-m4-sealed-and-the-hooks-that-never-fired.md) |

## Quickstart

Prerequisites: Claude Code ≥ 2.1.163 (2.1.195+ preferred), `bash`, `python3`, `curl`, and a Z.ai credential — either a **Coding Plan** subscription token or a metered **API key**.

```bash
git clone https://github.com/AmbitiousRealism2025/Albion.git && cd Albion

export ALBION_ZAI_TOKEN="<your Z.ai token>"   # plan lane is the default
bin/albion-doctor --live    # full health matrix incl. a 1-token live probe
bin/albion                  # Claude Code on GLM-5.2 + charter + plugin
```

| Command | What it does |
|---|---|
| `bin/albion` | The product: GLM-5.2 + ALBION.md charter + enforcement plugin |
| `bin/albion --vanilla` | Bare GLM-5.2 — the permanent A/B control arm |
| `bin/albion --doctor` / `bin/albion-doctor --live` | Health matrix; non-zero exit on any red cell |
| `bin/albion-vision <image>` | One-shot image description via GLM-4.6V (works on both auth lanes) |
| `bin/albion-compile --check` | Verifies the charter matches its `manifest/` source fragments |

Auth lanes: `ALBION_AUTH_LANE=plan` (default; prompt-metered subscription) or `api` (token-metered). See `env/albion-env.sh` for the full variable reference. Empirical detail worth knowing: plan tokens work **only** on Z.ai's Anthropic-compatible endpoint — Albion routes this correctly and its diagnostics name the notorious `1113` wrong-lane error for what it is.

## The architecture

1. **`charter/ALBION.md` — the operating system (always-on).** The fable-mode discipline (evidence-gated claims, state maps, competing hypotheses, counterexample-first recovery, independent verification) merged with the orchestration charter (intent gate, delegation, task tracking) in one voice. Compiled from `manifest/sections/` by `bin/albion-compile`, so charter size is a build-time decision with a byte-exact drift gate.
2. **On-demand skills & agents** (`plugin/`) — `maturity-assessment`, `delegation`, `recovery`, `completion-gate`, `conductor`; agents `scout`, `counterexample-hunter`, `verifier`, `simplifier`, `quick` with wire-verified per-agent effort routing. fable-mode also ships standalone for stock Claude Code users.
3. **Hook enforcement suite** (`plugin/hooks`, `plugin/scripts`) — destructive-command guard, strike counter, workbench secrets scrubber, Stop-gate completion enforcement (which doubles as the conductor's completion-manifest signal), post-compaction state re-injection, and image-read interception. Every hook ships with recorded-payload tests; `albion-doctor` re-runs them on demand. The honest scope of what hooks can and cannot defend is in [`docs/security-model.md`](docs/security-model.md).
4. **Launcher + vision** (`bin/`) — Z.ai endpoint pinning, both auth lanes, `glm-5.2[1m]` model slots, cache hygiene, loud startup validation; vision is pluggable, with direct GLM-4.6V over HTTP as the default (no MCP dependency, same token, prompt-metered on the plan lane).

**The Conductor:** a documented protocol (and skill) for a frontier-model Claude Code session orchestrating GLM-backed Albion workers over tmux — files for signaling, tmux for transport, a completion manifest written by the Stop gate as the done-signal. Frontier judgment where it counts, GLM volume where it's cheap. Albion never *requires* it: standalone strength is the product.

## How Albion is built — and why the journal is worth reading

Albion is built by the pattern it ships. A frontier conductor — **Claude in Claude Code** — decomposes milestones into reviewable work packets and dispatches them to **GPT-5.5 via OpenAI's Codex CLI** in tmux, with file-based completion signaling and mechanical acceptance gates before every merge. GLM-5.2 never builds: it is the test subject, and building with it would confound the project's own experiments.

The [build journal](docs/build/log/) is deliberately unvarnished, because honest engineering records are rarer and more useful than clean ones. Highlights reviewers may find instructive:

- A worker **gamed a test counter** rather than report a scope conflict — caught in conductor review, fixed, and turned into standing protocol ([log 010](docs/build/log/010-m3-plugin-complete-and-a-gamed-counter.md)). The same conflict recurred three times afterward; every worker reported honestly.
- Albion's own hooks were **silently inert in real sessions** for two milestones — the exact defect class this project diagnosed in its predecessor — because a config array should have been a string and every verification layer shared the blind spot. Found by an exit test, fixed the same day, postmortem published ([log 012](docs/build/log/012-m4-sealed-and-the-hooks-that-never-fired.md)).
- Every acceptance is gated on CI, every worker diff is read hunk-by-hunk, and worker self-reports are never treated as evidence — a rule the journal repeatedly justifies.

The methodology is specified in [`docs/build/orchestration.md`](docs/build/orchestration.md); it doubles as a reusable, documented demonstration of orchestrating a frontier model across another vendor's coding CLI.

## Key empirical findings

- Atreides' hook layer was silently inert (wrong input contract vs. the real hook interface) — and Albion briefly repeated the class one level up (config loader vs. wire format). Both are documented; the second now has a schema test and a registration-check backlog item.
- GLM-5.2 is the top open-weights agentic coder but scores roughly half of Claude Opus on long-horizon benchmarks — the gap Albion's architecture targets.
- Live probes confirmed: hooks, native subagents, and per-task effort routing **work** under GLM-5.2; abstract skill auto-triggering **does not** (0/3) — hence the always-on compiled charter.
- **Coding Plan tokens authorize direct GLM-4.6V vision calls** on the plan's Anthropic-compatible endpoint (empirically verified; Z.ai's own model-list documentation omits this). Albion's doctor probes it live so a silent entitlement change is caught immediately.
- A medium orchestrated task costs ≈$1.20 on the API lane with warm cache — or ≈3 prompt-equivalents on a Coding Plan whose $18/mo tier covers 9–25 such tasks per 5-hour window.

## Roadmap

M0 ✅ → M1 ✅ → M2 ✅ → M3 ✅ → M4 ✅ → **M5 Telemetry + three-arm A/B bench** *(current)* → M6 OSS release 1.0 (pristine repo, one-command install) → M7 Hardening (provider abstraction, interactive conductor steering).

**Further out:** ports to Opencode (*Oakdale*) and Pi (*Bower Lake*) over the same harness-agnostic manifest and conductor protocol.

## Contributing & security

Contributions are welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md) for the test suite, portability rules, and how changes are reviewed. Security reports: [`SECURITY.md`](SECURITY.md); the honest threat model is [`docs/security-model.md`](docs/security-model.md).

## Disclosures

- Z.ai first-party serving routes prompts/code through servers in China; the roadmap includes a provider-abstraction toggle (US-resident hosts of the MIT open weights, or self-hosting) with documented quantization-quality caveats.
- Claude Code's built-in cost display is incorrect against non-Anthropic endpoints; Albion's telemetry (M5) is the source of truth.
- Vision-model behavior on the plan lane relies on an entitlement Z.ai's documentation does not list; the doctor's live probe is the tripwire if it changes.

## License

[MIT](LICENSE)
