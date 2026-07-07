# How Albion Is Built: Multi-Model Orchestration

Albion is not only *about* orchestration — it is **built by it**. The build process is itself a working demonstration of the pattern Albion ships: a frontier model acting as conductor, dispatching well-specified work packets to a different coding model in a different coding environment, with file-based signaling, mechanical verification, and a human maintainer above both.

This document specifies the methodology. The per-milestone journal lives in [`log/`](log/).

## Why build it this way

1. **The subject must not be the builder.** GLM-5.2 is the model under test in this project. Building Albion *with* GLM would confound every observation — "is this bug the code or the coder?" The implementation lane therefore uses a different model entirely.
2. **Model diversity catches monoculture bugs.** The conductor (Anthropic Claude, Fable 5) and the implementation lane (OpenAI GPT-5.5 via Codex CLI) have non-overlapping blind spots; the maintainer arbitrates.
3. **Dogfooding the Conductor.** Albion's Conductor skill (proposal §7) prescribes exactly this topology — frontier judgment dispatching volume implementation over tmux with file-based completion signaling. Every friction point in the build feeds the skill's design before it ships.
4. **The pattern is the point.** Orchestrating across vendors' coding CLIs — Claude Code, Codex CLI, and later Opencode and Pi — is a capability many people want and few have documented end-to-end. This build is the worked example.

## Roles

| Role | Who | Responsibilities |
|---|---|---|
| **Maintainer** | AmbitiousRealism2025 | Direction, review of packet plans, final authority on scope and merges |
| **Conductor** | Claude (Fable 5, later Opus 4.8) in Claude Code | Architecture, task decomposition into work packets, dispatch, fresh-context diff review against briefs, integration, git hygiene, build log |
| **Implementation lane** | GPT-5.5 (high reasoning) via `codex exec` | Executes work packets: code + tests, headless, workspace-sandboxed |
| **Test subject** | GLM-5.2 via Z.ai | Never builds; runs Albion sessions as experiment subjects (bench, A/B) |

**A note on the conductor model.** The conductor ran on Claude Fable 5 through Milestone 0, Milestone 1, and most of Milestone 2. Partway through the Milestone 2 enforcement layer, a Fable-tier dual-use safeguard flagged the security-tooling content (the secrets scrubber and destructive-command guard necessarily contain the credential and attack patterns they defend against) and the session continued on Claude Opus 4.8. This is recorded plainly because the build log's value is its honesty: the security-dense milestones are a natural fit for Opus, and the reasoning- and design-heavy milestones (the charter and skills) are where the Fable tier earns its place. The methodology — a frontier Claude conducting GPT-5.5 workers with mechanical gates — is unchanged by which Claude tier holds the baton.

## The protocol

1. **Brief.** The conductor writes each task as a work packet using the 7-section delegation template (TASK / EXPECTED OUTCOME / CONTEXT / MUST DO / MUST NOT DO / TOOLS ALLOWED / SUCCESS CRITERIA) into `.albion/handoff/<packet-id>/task.md`. Every brief references the repo's conventions file so style stays coherent across workers.
2. **Dispatch.** The packet runs in a tmux window for observability, headlessly:
   `codex exec` scoped to the repo (`-C`), workspace-write sandbox, final message written to `.albion/handoff/<packet-id>/last-message.md`. Process exit is the completion signal — no screen-scraping.
3. **Verify.** The conductor reviews `git diff` against the brief and runs the packet's SUCCESS CRITERIA tests. Acceptance is mechanical where possible (the packet's tests), semantic where necessary (conductor review).
4. **Integrate.** The conductor owns commits; workers produce diffs. Rework goes back as a revised brief, not an edit war.
5. **Log.** Each packet's outcome is journaled (see metrics below).

### Guardrails

- Workers never run with filesystem access beyond the repo workspace.
- Honor-system completion claims are worthless (the core research finding of this project); acceptance requires fresh tool evidence — tests run by the conductor, not asserted by the worker.
- The conductor never merges its own architecture unreviewed either: milestone plans are approved by the maintainer before dispatch.

## Metrics (accumulated in the build log)

| Metric | Why it matters |
|---|---|
| Packets dispatched / accepted first-pass | Delegation quality signal |
| Review findings per packet (by severity) | What the conductor's review layer actually catches |
| Rework cycles per packet | Brief clarity signal |
| Wall-clock per packet, conductor-time vs worker-time | The economics of the pattern |
| Cost/credits by lane (Anthropic / OpenAI / Z.ai) | Honest accounting of what multi-model building costs |

These numbers are published as-is, including failures. The credibility of this document depends on it.

## Session hygiene for long multi-phase runs (field-learned, 2026-07-06)

Two practices from an eight-phase real-world marathon (field observations,
build log 023):

- **Fresh session per phase, hydrated by the workspace.** A single continuous
  session degraded measurably in its late phases (unfinished deliverables,
  argument-instead-of-measurement), and the worker itself cited context
  exhaustion. The workspace already *is* the handoff — git history, the
  workbench board, prior phase manifests — and cold starts were proven to
  work. Do not push a saturated context through one more phase. (Charter v0.3
  §3 makes the same rule session-side.)
- **Gate on constraints, not just claims.** Both a GLM worker and a frontier
  model missed brief constraints on first submission in the same experiment —
  it is a universal failure class, not a model tier trait. The conductor's
  acceptance gate should mechanically diff the brief's explicit constraints
  (and any mid-phase directives) against the submitted evidence before
  accepting a manifest.

## Reusing this pattern

Nothing here is Albion-specific: any project can run a frontier conductor over `codex exec` (or any headless coding CLI) with the same brief format, tmux-for-observability / files-for-signaling transport, and mechanical acceptance gates. When Albion's Conductor skill ships, it packages this protocol; until then, this document plus the build log is the reference implementation.

---

*Methodology adopted 2026-07-04. See [`log/000-methodology.md`](log/000-methodology.md).*
