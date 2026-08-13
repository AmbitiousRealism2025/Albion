# Albion development record

This directory contains Albion's engineering history and experimental record.
The main [README](../../README.md) is for users. Start here when you want to
audit a claim, understand a design choice, or continue development.

The chronological journal is in [`log/`](log/). The optional multi-agent
workflow used to build the project is in
[`orchestration.md`](orchestration.md).

## Lineage and thesis

Albion succeeds [Atreides](https://github.com/AmbitiousRealism2025/Atreides).
Atreides used prompt instructions to organize Anthropic Claude. Albion runs
Claude Code with Z.ai's GLM-5.2 and moves some of that organization into files,
hooks, permissions, and tests.

The design assumes a capable model can still drift during a long task. Albion
therefore records deliverables and verification in a working board. It uses
Claude Code hooks for the checks that can be mechanical and keeps judgment in
the charter, agents, and human review.

## Current status

Version 0.3.0 is the current release. It includes:

- the launcher and interactive credential setup;
- the doctor and live endpoint probes;
- charter v0.3, compiled from `manifest/sections/`;
- the hook and session-state system;
- specialist agents and on-demand skills;
- GLM-4.6V vision, telemetry, and the A/B bench;
- a self-contained plugin package and marketplace distribution.

The marketplace package is published at
[AmbitiousRealism2025/albion-marketplace](https://github.com/AmbitiousRealism2025/albion-marketplace).
The v0.3 release gate passed the test suite and the live checks recorded in
[log 023](log/023-field-tuning-round.md).

## How the project was built

A Claude Code session acted as the conductor. It split milestones into work
packets and dispatched them to GPT-5.5 through the Codex CLI in tmux. The
conductor reviewed diffs and ran acceptance checks before merging the work.
GLM-5.2 was the test subject, not the implementation worker, so the same model
did not build and grade its own reliability layer.

The workflow is documented in [`orchestration.md`](orchestration.md). Albion
does not require it for normal use.

## Failures worth reading

The journal keeps mistakes because several of them changed the design:

- A worker changed a test counter to avoid reporting a scope conflict. Review
  caught it and the incident became a standing conductor rule. See
  [log 010](log/010-m3-plugin-complete-and-a-gamed-counter.md).
- The hooks passed schema checks but did not load in live Claude Code sessions.
  An exit test found that array-form commands needed to be strings. The suite
  now includes a live registration smoke check. See
  [log 012](log/012-m4-sealed-and-the-hooks-that-never-fired.md).
- The first long-task comparison found that the charter improved convergence at
  high reasoning effort, but the board and reinjection system looked too heavy.
  That result led to process metrics and a shorter charter. See
  [log 014](log/014-long-horizon-ab-what-the-charter-buys.md).
- The original five-tier charter opened a real board in only 1 of 10 headless
  runs. A shorter one-rule design opened one in 7 of 10 runs across the recorded
  batches. The project shipped the smaller design after a separate validation
  batch. See [logs 020](log/020-lean-charter-headless-ab.md),
  [021](log/021-lean-charter-n6-and-interactive-recovery.md), and
  [022](log/022-charter-v02-the-trim.md).

## What the experiments support

The evidence supports a process claim, not an outcome claim.

- At maximum reasoning effort, both Albion and vanilla GLM-5.2 solved the
  current benchmark tasks. The charter did not increase solve rate in those
  batches.
- Albion sessions were more likely to leave a task board and verification
  record after the charter was simplified.
- The v0.3 validation ran 16 sessions. Both charter versions solved 8 of 8
  tasks. V0.3 left an evidence-complete board in 8 of 8 runs, while v0.2 missed
  both `revenue-pipeline` boards. V0.3 took about 17 percent longer.
- Live probes confirmed that Claude Code hooks, subagents, and per-agent effort
  selection reached GLM-5.2. Abstract skill auto-triggering failed in 3 of 3
  probes, which is why the short charter names skill triggers explicitly.
- A recorded medium orchestrated task cost about $1.20 on the metered API lane
  with a warm cache. That is a dated observation, not a current provider price
  guarantee.

Sample counts are small. Several investigative and delegation-heavy paths have
not been forced by a benchmark fixture. Read the linked logs before using these
results to predict another repository or model.

## Roadmap

M0 through M6 and the first field-tuning round are complete. Candidates for M7
include:

- provider abstraction for other hosts or self-hosting;
- interactive conductor steering;
- a benchmark fixture that forces investigative escalation;
- a first-class `board_real` benchmark metric;
- investigation of vision availability in field workspaces.

OpenCode and Pi ports remain ideas rather than scheduled releases.

## Development trail

| Stage | Result | Record |
|---|---|---|
| M0, research and proposal | Z.ai lane probes and the initial design | [Research](../research/atreides-analysis.md), [proposal](../proposal/albion-proposal.md) |
| M1, launcher and doctor | Both auth lanes, model routing, and diagnostics | [Log 004](log/004-milestone-1-closeout.md) |
| M2, hooks and state | Session state plus the enforcement hooks | [Log 008](log/008-milestone-2-closeout.md) |
| M3, charter and plugin | Compiled charter, skills, agents, and plugin layout | [Log 011](log/011-m3-sealed-exit-test.md) |
| M4, vision and conductor | GLM-4.6V helper and completion signaling | [Log 012](log/012-m4-sealed-and-the-hooks-that-never-fired.md) |
| M5, telemetry and bench | Cost records, benchmark runner, and first A/B report | [Log 013](log/013-m5-sealed-first-ab-report.md) |
| M6, release engineering | Installer, CI, community files, registration check, and coexistence rules | [Log 015](log/015-m6-oss-release-engineering.md) |
| Charter v0.2 | Process metrics, lean-charter tests, and the validated trim | [Logs 019](log/019-bench-process-metrics.md) through [022](log/022-charter-v02-the-trim.md) |
| Version 0.3 | Completion integrity, verification fixtures, two new skills, and charter v0.3 | [Log 023](log/023-field-tuning-round.md) |
