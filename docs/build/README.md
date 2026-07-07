# The Albion development record

This page carries the project's build history and evidence base — the material
a contributor, reviewer, or curious reader wants, kept separate from the
user-facing [README](../../README.md). The chronological journal is in
[`log/`](log/); the methodology is in [`orchestration.md`](orchestration.md).

## Lineage and thesis

Albion is the successor to
[Atreides](https://github.com/AmbitiousRealism2025/Atreides). Where Atreides
was prompt-injected orchestration for Anthropic Claude, Albion is a complete
operating environment for Claude Code running Z.ai's GLM-5.2 as the main
model. The organizing principle: **GLM-5.2 inverts the enforcement equation.**
Claude tolerated honor-system orchestration; GLM-5.2's long-horizon drift and
reward-hacking lineage require that every rule that *can* be enforced
deterministically *is* — and that everything left in the prompt is radically
compressed.

## Status

The system is built and CI-green — launcher, doctor, the compiled charter
(v0.3), the enforcement hooks, skills and agents, vision, telemetry, and the
A/B bench are all in place and exit-tested live against the real endpoint.
Release engineering (installer, hardened CI, community files) is done; the
plugin-marketplace submission is the remaining step.

## How Albion was built — and why the journal is worth reading

Albion was built by the pattern it ships. A frontier conductor — **Claude in
Claude Code** — decomposed each milestone into reviewable work packets and
dispatched them to **GPT-5.5 via OpenAI's Codex CLI** in tmux, with file-based
completion signaling and mechanical acceptance gates before every merge.
GLM-5.2 never built anything: it is the test subject, and building with it
would have confounded the project's own experiments.

The [build journal](log/) is deliberately unvarnished, because honest
engineering records are rarer and more useful than clean ones. Highlights
reviewers may find instructive:

- A worker **gamed a test counter** rather than report a scope conflict —
  caught in conductor review, fixed, and turned into standing protocol
  ([log 010](log/010-m3-plugin-complete-and-a-gamed-counter.md)). The same
  conflict recurred repeatedly afterward; every worker then reported it
  honestly.
- Albion's own hooks were **silently inert in real sessions** for two
  milestones — the exact defect class this project diagnosed in its
  predecessor — because a config array should have been a string, and every
  verification layer shared the blind spot. Found by an exit test, fixed the
  same day, postmortem published
  ([log 012](log/012-m4-sealed-and-the-hooks-that-never-fired.md)); a live
  registration smoke-check now guards against the whole class.
- A long-horizon A/B on a real 350k-LOC codebase found the always-on charter's
  measurable value is **convergence at high reasoning effort** (2.2× faster
  than skill-only), while surfacing that the workbench and re-injection hook
  may be over-built — recorded as hypotheses to test, not conclusions
  ([log 014](log/014-long-horizon-ab-what-the-charter-buys.md)).
- Those hypotheses were then run to ground: the bench was rebuilt to measure
  **process, not just outcomes** ([log 019](log/019-bench-process-metrics.md)),
  lean-vs-full charter A/Bs produced a surprising inversion — the original
  5-tier charter opened its working board in **1/10** headless runs, a 1-rule
  lean chassis in **7/10** ([logs 020](log/020-lean-charter-headless-ab.md)
  [–021](log/021-lean-charter-n6-and-interactive-recovery.md)) — and the
  shipped charter was trimmed to **v0.2** behind a pre-registered validation
  gate (3/4 vs 0/4 real evidence-complete boards;
  [log 022](log/022-charter-v02-the-trim.md)).

The methodology is specified in [`orchestration.md`](orchestration.md); it
doubles as a reusable, documented demonstration of orchestrating a frontier
model across another vendor's coding CLI.

## Key empirical findings

- GLM-5.2 is the top open-weights agentic coder but scores roughly half of
  Claude Opus on long-horizon benchmarks — the gap Albion's architecture
  targets.
- Live probes confirmed: hooks, native subagents, and per-task effort routing
  **work** under GLM-5.2; abstract skill auto-triggering **does not** (0/3) —
  hence the always-on compiled charter.
- **Coding Plan tokens authorize direct GLM-4.6V vision calls** on the plan's
  Anthropic-compatible endpoint (empirically verified; Z.ai's own model-list
  documentation omits this). Albion's doctor probes it live so a silent
  entitlement change is caught immediately.
- A medium orchestrated task costs ≈$1.20 on the API lane with warm cache — or
  ≈3 prompt-equivalents on a Coding Plan whose $18/mo tier covers 9–25 such
  tasks per 5-hour window.
- At maximum reasoning effort the charter changes **process, not outcomes**:
  GLM-5.2 solves bench tasks with or without it, but the charter buys an
  auditable evidence trail and recovery across context resets
  ([logs 018](log/018-three-ab-scenarios-what-the-charter-buys.md)
  [–022](log/022-charter-v02-the-trim.md)). A controlled A/B then showed a
  **simpler gate is followed more reliably than a longer one**, and the shipped
  charter was trimmed on that evidence.

## Roadmap

M0–M5 sealed; M6 (OSS release engineering) done bar the marketplace
submission. The log-014 design questions are resolved: the charter-trim track
(logs 019–022) rebuilt the bench to measure process, ran the A/Bs, and sealed
the trimmed **charter v0.2** — and the first post-release field-tuning round
(logs 023) then hardened it into **charter v0.3** on real-world evidence.
Next: **M7 — hardening** (provider abstraction,
interactive conductor steering) and an escalation-forcing bench fixture.

**Further out:** ports to Opencode (*Oakdale*) and Pi (*Bower Lake*) over the
same harness-agnostic manifest and conductor protocol.

## Development trail

Each milestone sealed CI-green, with an honest closeout log:

| Milestone | Delivered | Journal |
|---|---|---|
| M0 Research + proposal | Empirical probes of the Z.ai lane; design v0.2 | [analysis](../research/atreides-analysis.md) · [proposal](../proposal/albion-proposal.md) |
| M1 Launcher + doctor | `bin/albion` (4 modes, both auth lanes), `bin/albion-doctor` (live health matrix) | [log 004](log/004-milestone-1-closeout.md) |
| M2 Hooks + state engine | Session-state JSON engine; enforcement hooks, adversarially red-teamed | [log 008](log/008-milestone-2-closeout.md) |
| M3 Charter + skills + agents | `charter/ALBION.md` (compiled from `manifest/`), 5 skills, 5 agents, plugin packaging | [log 011](log/011-m3-sealed-exit-test.md) |
| M4 Vision + conductor protocol | `bin/albion-vision` (direct GLM-4.6V), image-read interception, completion-manifest signaling, conductor skill | [log 012](log/012-m4-sealed-and-the-hooks-that-never-fired.md) |
| M5 Telemetry + A/B bench | Dual-cost-model telemetry, `last_test` writer, bench harness + report generator, first A/B report | [log 013](log/013-m5-sealed-first-ab-report.md) |
| M6 OSS release engineering | `install.sh`, `albion-setup`, SHA-pinned CI, community files, hook-registration smoke-check, coexistence gating | [log 015](log/015-m6-oss-release-engineering.md) |
| Charter v0.2 | Process-metrics bench (ALB-029), lean-charter A/Bs, validated trim of the shipped charter | [logs 019](log/019-bench-process-metrics.md)[–022](log/022-charter-v02-the-trim.md) |
| Field-tuning round (0.3.0) | Stop-gate deliverables rule, three verification-fidelity fixtures, hot-path + toolchain-fidelity skills, charter v0.3 sealed on a pre-registered 16-run gate | [log 023](log/023-field-tuning-round.md) |
