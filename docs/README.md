# Documentation

Use this page to find the shortest route into Albion's documentation.

## Use Albion

- [GLM-5.2 setup](glm-5.2-setup.md) covers installation, authentication lanes,
  manual Claude Code configuration, vision, and troubleshooting.
- [Security model](security-model.md) states what the permissions rules and
  hooks can and cannot stop.
- [Packaging](packaging.md) explains the self-contained marketplace build.

## Contribute

- [Contributing guide](../CONTRIBUTING.md) lists the required checks and review
  rules.
- [Conventions](../CONVENTIONS.md) defines the shell, JSON, path, and test
  conventions.
- [Security policy](../SECURITY.md) explains private reporting and supported
  versions.
- [Charter manifest](../manifest/albion-manifest.yaml) is the source map for the
  compiled charter. Edit `manifest/sections/`, then run `bin/albion-compile`.

## Inspect the evidence

- [Development record](build/README.md) summarizes the project history,
  experiments, failures, and roadmap.
- [Build log](build/log/) contains the chronological engineering record.
- [Benchmark guide](../bench/README.md) documents task fixtures and run records.
- [Telemetry guide](../telemetry/README.md) documents token and cost records.
- [First A/B report](../bench/reports/m5-first-ab-report.md) is the initial small
  Albion versus vanilla comparison.
- [Field-tuning report](build/log/023-field-tuning-round.md) records the v0.3
  validation batch.

## Optional orchestration workflow

- [Conductor protocol](build/orchestration.md) describes the tmux workflow used
  to coordinate coding agents during Albion's development. Albion does not
  require this workflow for ordinary use.
