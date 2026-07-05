# Build Log 015 — M6: OSS Release Engineering

**Date:** 2026-07-05 (overnight autonomous session, maintainer-authorized)
**Milestone:** M6 — the pristine repo. **Status: substantially complete, CI-green.** The remaining step (plugin-marketplace submission) is externally gated and left for the maintainer.

## Scope discipline for an autonomous session

This milestone ran unattended with explicit authorization to take M6 end-to-end. The diagnostic in log 014 reshaped what M6 *could* be — it argued the workbench and the SessionStart re-injection hook are vestigial and floated a `--lite` charter. **Those are design decisions and were deliberately NOT made here.** An overnight agent should not unilaterally rip behavioral subsystems out of the product on n=1 evidence. M6 was therefore scoped to the safe, mechanical "release engineering" deliverables; the design calls are queued for the maintainer (see below).

## Delivered (each committed CI-green)

1. **One-command installer** (`install.sh`, ALB-025). Prereq checks (bash/python3/curl/git + Claude Code version gate), absolute repo-rooted symlinks for the four `bin/` tools into `~/.local/bin` (or `--prefix`), idempotent, refuses to clobber non-symlinks or symlinks pointing outside the repo, PATH + token guidance, optional offline doctor. bash 3.2-safe. Conductor-probed live: the symlinked launcher resolves the plugin dir correctly through the symlink walk; re-run clean; collision-safe.

2. **Hook registration smoke-check** (`tests/tools/verify-registration.sh`). The highest-value item: it launches a minimal live session and confirms the plugin's Stop gate actually fired (wrote a completion manifest) — proving Claude Code *registers* the hooks. This closes the exact blind spot that let the hooks sit inert for two milestones (log 012): every prior check invoked hook scripts directly and never tested loading. Conductor-verified live: **PASS**. A hermetic guard test covers the tool's structure and no-token skip; the live probe is maintainer-run (needs a token, so not in CI).

3. **Effort-default fix** (doctor `effort` check + settings correction). Dogfooding surfaced that Albion sessions ran at `effortLevel: high`, not the `xhigh`/GLM-max the design mandates, because nothing ever set it. Fixed and guarded so it cannot silently regress. Full story in log 014.

4. **CI supply-chain hardening.** `actions/checkout` pinned to a commit SHA (v5.0.0, Node 24 — also resolves the standing Node 20 deprecation), workflow dropped to least-privilege `permissions: contents: read`.

5. **Community surface.** Issue forms (bug/feature) with a private-security-advisory contact link, a PR template bound to the CONTRIBUTING checklist, `CODEOWNERS`, and `CHANGELOG.md`. (`CONTRIBUTING.md` and `SECURITY.md` landed earlier this session.)

## Test suite

22 → **25 files**, green on macOS and Ubuntu; CI green on every push this milestone.
*(Correction, post-audit: this originally misstated the starting count as 12; log 013 sealed M5 at 22 files.)*

## Queued for the maintainer (design decisions, not done autonomously)

From the log-014 diagnostic, in priority order:
1. **Re-scope or retire the workbench and the SessionStart re-injection hook** — four long-horizon runs, zero workbench engagement; the charter's convergence prevents the compaction the re-injection hook exists to survive. A `--lite` charter A/B (trivial via the compile pipeline) is the clean test.
2. **Keep the always-on task-tracking** — the one charter feature with a *measured* benefit (2.2× convergence at max effort; log 014).
3. **Fix the bench methodology** — the `--vanilla` control is contaminated by the user-scope `fable-mode` skill; a true bare arm must disable it. And build tasks that stress the enforcement layer (destructive actions, hidden-acceptance-gate reward-hacking, multi-session) rather than read-only analysis.
4. **Marketplace submission** — the externally-gated remaining M6 step; needs the maintainer's account.
5. **Repeated-trials confirmation** of the log-014 convergence and vestigial-hook hypotheses (all currently n=1).

## Honest note

M6 makes the repo *installable and credible*, not *finished*. The most important open questions are behavioral (what the charter should contain), and this session correctly left them for a human. The release engineering is done; the product design conversation is the next one.
