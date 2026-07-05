# Changelog

All notable changes to Albion are recorded here. This project adheres to
[Semantic Versioning](https://semver.org). Dates are UTC.

## [Unreleased]

### Added
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
