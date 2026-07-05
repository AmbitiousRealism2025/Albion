# Changelog

All notable changes to Albion are recorded here. This project adheres to
[Semantic Versioning](https://semver.org). Dates are UTC.

## [Unreleased]

### Added
- One-command fresh-machine installer (`install.sh`).
- Hook **registration** smoke-check — verifies Claude Code actually loads the
  plugin hooks, not just that the scripts run when invoked directly.
- GitHub community files: issue forms, pull-request template, `CODEOWNERS`,
  `CONTRIBUTING.md`, `SECURITY.md`.
- `albion-doctor` **effort** check — warns when the resolved `effortLevel` is not
  `xhigh` (GLM-max), the depth Albion's design requires.

### Changed
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
