# Build Log 009 — M3 Kickoff: Charter Authored, Skills + Agents Fan-Out

**Date:** 2026-07-04
**Milestone:** M3 — ALBION.md + skills + agents (plugin). **Status: in progress.**
**Conductor:** Fable 5 (fresh session, rehydrated from `SESSION-HANDOFF.md` exactly as designed — the handoff doc worked on first use).

## The charter is conductor-written — and shorter than planned

Per the handoff rule, `charter/ALBION.md` was authored directly by the conductor, not dispatched: it is the behavioral core, and its voice *is* the product. The maintainer approved the packet plan and one deviation before any dispatch:

- **323 dense lines instead of the proposal's ~550–650 target.** All seven mandated structural elements are present (contract verbatim, intent gate, operating loop, workbench spec, delegation roster, enforcement-layer semantics, re-anchor line). Reaching 600 lines would have meant worked examples, not more rules; the maintainer chose density. The compliance-vs-coverage curve is explicitly the hypothesis the M5 bench A/Bs, and the embedded `albion:section` markers make growth a compile-time decision.
- **The charter follows the hooks, not the skill.** The standalone skill describes a flat workbench (`.agent-workbench/fable-mode/task.md`); the shipped M2 stop-gate and session-inject hooks require per-task directories (`.agent-workbench/fable-mode/<task-slug>/`). The charter and the newly vendored `plugin/skills/fable-mode-glm-5-2/` both use the per-task layout. Enforcement reality wins over documentation lineage.

## The charter's first act was to break the test suite

Creating `charter/ALBION.md` immediately failed `test_launcher.sh` — a latent hermeticity bug: the `ALBION_MODEL` case ran with `ALBION_CHARTER` unset, so the launcher's fallback path (`${repo_root}/charter/ALBION.md`) resolved for the first time ever and appended two argv entries the test didn't expect. The case is now pinned to an explicit missing-charter path.

**Lesson (CONVENTIONS-class):** a test that leaves an env override unset is not testing "feature absent" — it is testing "repo happens not to ship the file yet." Every fallback-path test must pin the fallback target explicitly.

## First parallel fan-out of M3: ALB-013 + ALB-014

Two packets dispatched simultaneously (disjoint file lanes, disjoint test files — the M2 shared-tree rule baked into both briefs' MUST-NOT-DO):

- **ALB-013** — crown-jewel skills: `maturity-assessment`, `delegation`, `recovery`, `completion-gate`. Each ≤50 lines, extends its charter section without restating it, and carries load/don't-load triggers in the description.
- **ALB-014** — agent roster: `scout`, `counterexample-hunter`, `verifier`, `simplifier`, `quick`. Exact tool sets, wire-verified `effort:` frontmatter, `model: haiku` on `quick`, explicit output contracts and termination criteria.

Both were **first-pass accepts** — the first packet cycle in the project with zero rework. Review gate: scope check exact (11/11 allowed paths), suite 14/14 on the merged tree, CI-equivalent shellcheck clean, and three **mutation probes** confirming the new structural tests are not hollow (forbidden tool on `scout`, planted AWS-key literal, frontmatter name mismatch — all caught). Both workers correctly ignored each other's untracked files per the shared-tree rule and said so in their reports.

## Process friction worth recording

The session's permission classifier denied `git push origin main` (direct-to-default-branch policy). The conductor-owns-git methodology assumed direct pushes; M3 commits are accumulating locally pending a maintainer push or a permission rule. Acceptance-on-CI-green is therefore *deferred*, not skipped: the gate applies at push time.

## Metrics (cycle, not milestone)

| Metric | Value |
|---|---|
| Packets dispatched / accepted | 2 / 2 (first-pass, zero rework) |
| Conductor-lane deliverables | charter (323 lines), vendored skill + layout fix, launcher-test fix, 2 briefs |
| Genuine defects caught | 1 (latent test hermeticity, surfaced by the charter's existence) |
| Mutation probes run / caught | 3 / 3 |
| Test suite | 14 files green (12 → 14) |
| Remaining in M3 | ALB-015 (manifest→compile pipeline), ALB-016 (plugin.json + doctor manifest-diff), end-to-end exit test |
