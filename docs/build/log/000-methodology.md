# Build Log 000 — Methodology Adopted

**Date:** 2026-07-04
**Phase:** pre-implementation (research and proposal v0.2 complete)

## Decision

Albion will be built by multi-model orchestration, per [`../orchestration.md`](../orchestration.md):

- **Conductor:** Claude (Fable 5) in Claude Code — architecture, work-packet decomposition, dispatch, review, integration.
- **Implementation lane:** GPT-5.5 (high reasoning) via `codex exec`, in tmux, workspace-sandboxed, file-based completion signaling.
- **GLM-5.2 explicitly excluded from building** — it is the test subject; building with it would confound the project's own experiments.

## Rationale recorded at adoption time

- Dogfoods the Conductor topology (proposal §7) before the skill exists.
- Model diversity between conductor and implementer; maintainer above both.
- The build itself becomes a reusable, honestly-metered demonstration of frontier-model orchestration across vendor coding CLIs — documentation with standalone community value.

## Next entries

- 001 — Codex lane smoke test (dispatch → exec → output file → review, one trivial packet).
- 002 — Milestone 1 packet plan (maintainer-approved) and first real dispatches.
