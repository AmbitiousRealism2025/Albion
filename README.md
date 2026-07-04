# Albion

**A GLM-5.2 orchestration system for Claude Code, built around fable-mode.**

Albion is the successor to [Atreides](https://github.com/AmbitiousRealism2025/Atreides). Where Atreides was prompt-injected orchestration for Anthropic Claude, Albion is designed for a custom Claude Code environment running **Z.ai's GLM-5.2** as the main model, with the **fable-mode-glm-5-2** operating discipline baked into its core and deterministic hooks as its enforcement layer.

**The goal:** give people who like Claude Code a lower-cost option that does not sacrifice too much. MIT licensed — use it, fork it, build on it.

The organizing principle: **GLM-5.2 inverts the enforcement equation.** Claude tolerated honor-system orchestration; GLM-5.2's long-horizon drift and reward-hacking lineage require that every rule that *can* be enforced deterministically *is* — and that everything left in the prompt is radically compressed.

## Status

**Phase: research & proposal (v0.2).** The deep-research mission is complete and the proposal has been through its first maintainer review. Next: planning (Milestone 1 breakdown).

## Documents

| Document | What it is |
|---|---|
| [`docs/research/atreides-analysis.md`](docs/research/atreides-analysis.md) | Comprehensive research analysis: Atreides (repo + DeepWiki), the fable-mode skill, GLM-5.2's capability profile, live empirical probes against the Z.ai endpoint, component verdict map, design tensions |
| [`docs/proposal/albion-proposal.md`](docs/proposal/albion-proposal.md) | The v0.2 design proposal: unified ALBION.md operating system, hook enforcement suite, agent roster, vision subsystem, the Conductor, cost model, OSS packaging, roadmap |
| [`docs/proposal/albion-companion.html`](docs/proposal/albion-companion.html) | Visual companion to the proposal |

*(Raw agent research reports are retained by the maintainer outside the public repo — they document a specific machine's environment. Their findings are fully synthesized into the analysis document.)*

## The architecture (summary)

1. **`ALBION.md` — a unified operating system (~600 lines, always-on).** The fable-mode discipline (evidence-gated claims, state maps, competing hypotheses, counterexample-first recovery, independent verification) merged with the orchestration charter (intent gate, delegation, task tracking) in one voice. Baking fable-mode in dissolves the skill-triggering problem entirely — live probes showed abstract skill descriptions never auto-trigger under GLM-5.2.
2. **On-demand skills & agents** — maturity assessment, delegation, recovery, completion reference; scout / counterexample-hunter / verifier / simplifier / quick. fable-mode also ships as a standalone skill for stock Claude Code users.
3. **Hook suite** — deterministic enforcement: strike counting, a Stop-hook completion gate, destructive-command guard, secrets scrubbing, post-compaction state re-injection, and image-read interception (vision routing).
4. **Launcher (`albion`)** — Z.ai endpoint, both auth lanes (Coding Plan and API key), `glm-5.2[1m]` model slots, cache hygiene, loud startup validation, plus `albion --vanilla` as a permanent A/B control arm.

**Vision:** GLM-5.2 is not a vision model, so vision is pluggable — GLM-4.6V by default (same Z.ai key), with Claude / Gemini / OpenAI / external-agent alternates, integrated transparently via the image-read hook.

**The Conductor:** a skill that works in both stock Claude Code and Albion — a Fable-driven Claude Code session orchestrates GLM-backed Albion workers over tmux (files for signaling, tmux for transport and live observability). Frontier judgment where it counts, GLM volume where it's cheap. Albion never *requires* it: standalone strength is the product.

## How Albion is built

Albion is built by the same pattern it ships. A frontier conductor — **Claude (Fable 5) in Claude Code** — decomposes milestones into reviewable work packets and dispatches them to **GPT-5.5 (high reasoning) via OpenAI's Codex CLI** (`codex exec`) in tmux, with file-based completion signaling and mechanical acceptance tests before every merge. GLM-5.2 never builds: it is the test subject, and building with it would confound the project's own experiments.

The methodology and an honestly-metered build journal (acceptance rates, review findings, rework cycles, cost per lane — failures included) live in [`docs/build/`](docs/build/orchestration.md). Beyond producing Albion, it's intended as a reusable, documented demonstration of orchestrating a frontier model across other vendors' coding CLIs.

## Key research findings

- Atreides' hook enforcement layer was **silently inert** (wrong input contract and exit codes vs the real Claude Code hook interface).
- GLM-5.2 is the top open-weights agentic coder but scores **half of Claude Opus on SWE-Marathon** — the long-horizon gap Albion's architecture is built to close.
- Live probes confirmed: hooks, native subagents, and per-task effort routing **work** under GLM-5.2; abstract skill auto-triggering **does not** (0/3).
- A medium orchestrated task costs **≈$1.20** on the API with warm cache — or ≈3 prompt-equivalents on a Coding Plan whose $18/mo Lite tier covers 9–25 such tasks per 5-hour window.

## Roadmap

M0 Verification *(largely complete)* → M1 Launcher + doctor → M2 Hooks + session-state → M3 Unified ALBION.md + skills + agents (plugin) → M4 Vision + Conductor → M5 Telemetry + A/B bench *(continuous)* → M6 OSS release 1.0 → M7 Hardening.

**Further out:** ports to Opencode (*Oakdale*) and Pi (*Bower Lake*) over the same harness-agnostic manifest and conductor protocol.

## Disclosures

- Z.ai first-party serving routes prompts/code through servers in China; the design includes a provider-abstraction toggle (US-resident hosts of the MIT open weights, or self-hosting) with documented quantization-quality caveats.
- Claude Code's built-in cost display is incorrect against non-Anthropic endpoints; Albion's telemetry is the source of truth.

## License

[MIT](LICENSE)

---

*Research mission run 2026-07-04: 11 agents, 291 tool calls, including live wire-level probes against `api.z.ai/api/anthropic`.*
