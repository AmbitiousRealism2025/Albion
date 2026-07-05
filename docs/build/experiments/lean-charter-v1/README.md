# Lean charter v1 — experimental instrument (not a product mode)

This directory archives the lean charter variant used in the build-log-020
headless A/B, so the experiment is reproducible. It is a **throwaway
instrument**: the maintainer's standing decision (log 018, project memory) is
that Albion ships exactly one charter — if this experiment's line of evidence
holds up, the *shipped* charter gets trimmed; a selectable "lite mode" will not
be added.

Composition: the shipped charter's preamble, contract, communication, and
re-anchor sections verbatim; lean rewrites of the intent gate (3 tiers instead
of 5, single board tier), the workbench (baseline `task.md` +
`verification.md` only), and the enforcement table (dangling cross-references
to dropped sections removed); the operating loop, full-board tiers, delegation
table, and skills catalog dropped. 138 lines compiled vs 350.

Recompile and run instructions are in the header of `lean-manifest.yaml`.
Results and interpretation: build logs 020 (headless A/B), 021 (n=6 +
interactive recovery), and 022 (the outcome).

**This instrument's line of evidence is concluded:** the maintainer approved
the trim and the shipped charter is now v0.2 — the lean chassis with the
delegation/skills tables and an evidence-triggered escalation section re-added
(ALB-030, validated 3/4 vs 0/4 real boards before sealing). The directory
stays as the reproducible record of what was actually run.
