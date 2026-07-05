# Changelog

All notable changes to Albion are recorded here. This project adheres to
[Semantic Versioning](https://semver.org). Dates are UTC.

## [Unreleased]

### Added
- Published the plugin marketplace
  ([AmbitiousRealism2025/albion-marketplace](https://github.com/AmbitiousRealism2025/albion-marketplace))
  carrying the packaged v0.2.0 plugin; the README documents marketplace
  install as the primary path.

## [0.2.0] — 2026-07-05

First tagged release: the complete system — launcher, doctor, charter v0.2,
enforcement hooks, skills and agents, vision, telemetry, bench, installer, and
self-contained plugin packaging — CI-green and exit-tested live against the
real endpoint.

### Added
- **Bench process metrics** (ALB-029): run records carry schema
  `albion-bench-run/v2` with a workbench artifact inventory (`engaged`,
  `evidence_complete`, per-task file listing), and `bench/report` compares arms
  on `evidence_complete_rate` alongside solve rate. v1 records remain
  ingestible.
- The lean-charter experiment instrument is archived under
  `docs/build/experiments/lean-charter-v1/` and recompiles byte-identical to
  the artifact used in the published runs.
- **Self-contained plugin packaging** (`bin/albion-package`): assembles a single
  marketplace-ready directory that is both a valid Claude Code plugin and a
  complete Albion install (it carries the launcher, `env/`, `charter/`, `config/`,
  and `state/`). The launcher, doctor, and hooks resolve paths in both the dev and
  packaged layouts. Verified live: a session launched from the package registers
  and fires its hooks.
- One-command fresh-machine installer (`install.sh`) and `bin/albion-setup`, an
  interactive credential configurator (hidden input, mode-600 secrets file).
- **Coexistence with stock Claude Code**: every plugin hook now gates on an
  `ALBION_ACTIVE` marker that only the `albion` launcher sets, so the plugin is
  inert in stock `claude` sessions even when enabled globally; and Albion's
  `xhigh` effort is scoped to its own sessions via `--settings` rather than the
  user's global config.
- Dedicated vision credential/lane: `ALBION_VISION_TOKEN` and `ALBION_VISION_LANE`
  let a metered user point GLM-4.6V at a separate key or lane from the main model.
- Hook **registration** smoke-check — verifies Claude Code actually loads the
  plugin hooks, not just that the scripts run when invoked directly.
- GitHub community files: issue forms, pull-request template, `CODEOWNERS`,
  `CONTRIBUTING.md`, `SECURITY.md`; and a [GLM-5.2 setup guide](docs/glm-5.2-setup.md).
- `albion-doctor` **effort** check — verifies Albion's shipped effort config is
  `xhigh` (GLM-max), the depth Albion's design requires.

### Changed
- The README is now **purely user-facing** — what Albion is, install,
  quickstart, coexistence, honest expectations, disclosures. The development
  history (build methodology, journal highlights, milestone trail, empirical
  findings, status) moved intact to `docs/build/README.md`, the development
  record.
- **Charter v0.2 — the trim** (ALB-030): the intent gate went from five tiers to
  three with one non-negotiable board rule; the 103-line operating loop became a
  31-line evidence-triggered escalation section; delegation was tightened. 222
  lines from 350. Sealed only after a pre-registered A/B showed the new document
  opens real, evidence-complete working boards 3/4 headless where the old one
  scored 0/4 (solve rate unchanged) — see build logs 019–022 for the evidence
  trail.
- CI now pins `actions/checkout` to a commit SHA (supply-chain hardening) and runs
  with least-privilege `permissions: contents: read`.

### Fixed
- Plugin hooks were declared with array-form commands, which Claude Code silently
  ignores; every hook is now string-form and a schema test enforces it. (The
  enforcement layer was inert in real sessions before this fix.)
- The Stop gate's `last_test` state key is now actually written by the strike hook
  (it was read by three consumers but never produced).
- Albion sessions now run at the `xhigh`/GLM-max effort the design specifies rather
  than silently inheriting a lower ambient default.

## [0.1.0] — pre-release

Milestones M1–M5, developed in the open via multi-model orchestration (see
`docs/build/`). Launcher + doctor, the hook enforcement suite + session-state
engine, the compiled `ALBION.md` charter with crown-jewel skills and agent roster,
the vision subsystem (`albion-vision`) and conductor protocol, and the
telemetry + A/B bench. Not yet tagged; `main` is the supported line pre-1.0.
