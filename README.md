# Albion

**A GLM-5.2 orchestration system for Claude Code, built around fable-mode.**

Albion is the successor to [Atreides](https://github.com/AmbitiousRealism2025/Atreides). Where Atreides was prompt-injected orchestration for Anthropic Claude, Albion is designed for a custom Claude Code environment running **Z.ai's GLM-5.2** as the main model, with the **fable-mode-glm-5-2** skill as its behavioral core and deterministic hooks as its enforcement layer.

The organizing principle: **GLM-5.2 inverts the enforcement equation.** Claude tolerated honor-system orchestration; GLM-5.2's long-horizon drift and reward-hacking lineage require that every rule that *can* be enforced deterministically *is* — and that everything left in the prompt is radically compressed.

## Status

**Phase: research & proposal (v0.1).** The deep-research mission is complete; the proposal is ready for review before moving to planning and implementation.

## Documents

| Document | What it is |
|---|---|
| [`docs/research/atreides-analysis.md`](docs/research/atreides-analysis.md) | Comprehensive research analysis: Atreides (repo + DeepWiki), the fable-mode skill, GLM-5.2's capability profile, live empirical probes against the Z.ai endpoint, component verdict map, design tensions |
| *(local only)* `docs/research/reports/` | Raw reports from the 11-agent research workflow — retained by the maintainer, excluded from the public repo (machine-specific details); fully synthesized into the analysis above |
| [`docs/proposal/albion-proposal.md`](docs/proposal/albion-proposal.md) | The design proposal: four-layer architecture, launcher spec, charter, fable-mode v2, hook enforcement suite, agent roster, state/memory model, telemetry, cost model, roadmap |
| [`docs/proposal/albion-companion.html`](docs/proposal/albion-companion.html) | Visual companion to the proposal |

## The four layers (summary)

1. **fable-mode v2 (skill)** — owns reasoning discipline: evidence-gated claims, state maps, competing hypotheses, counterexample-first recovery, verification.
2. **Charter (`ALBION.md`, <400 lines, always-on)** — owns routing & structure: the intent gate decides fable-on/off and effort tier, and invokes fable-mode *by name* (description-based auto-triggering is empirically unreliable under GLM-5.2).
3. **Hook suite** — owns enforcement: strike counting, a Stop-hook completion gate, destructive-command guard, secrets scrubbing, post-compaction state re-injection.
4. **Launcher (`albion`)** — owns configuration: Z.ai endpoint, `glm-5.2[1m]` model slots, effort defaults, cache hygiene, startup validation.

## Key research findings

- Atreides' hook enforcement layer was **silently inert** (wrong input contract and exit codes vs the real Claude Code hook interface).
- GLM-5.2 is the top open-weights agentic coder but scores **half of Claude Opus on SWE-Marathon** — the long-horizon gap Albion's architecture is built to close.
- Live probes confirmed: hooks, native subagents, and per-task effort routing **work** under GLM-5.2; abstract skill auto-triggering **does not** (0/3).
- The GLM plumbing (`claude-glm-env.sh`) and the Atreides orchestration layer both already exist on the author's machine — and had never been combined. Albion is that combination.

## Roadmap

M0 Verification *(largely complete)* → M1 Launcher + doctor → M2 Hooks + session-state → M3 Charter + skills + agents (plugin) → M4 Telemetry + A/B bench → M5 Hardening.

---

*Research mission run 2026-07-04: 11 agents, 291 tool calls, including live wire-level probes against `api.z.ai/api/anthropic`.*
