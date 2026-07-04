# Albion Conventions

## Shell style

Shell scripts use bash and start with `#!/usr/bin/env bash` followed by `set -euo pipefail`. Scripts must be shellcheck-clean, organized into small functions, and explicit about every failure path. Use `snake_case` for local variables and `SCREAMING_CASE` for exported environment variables. Do not hide command failures with broad redirects, unchecked pipelines, or best-effort cleanup that masks the original error.

## Tests

`tests/run.sh` discovers and runs every executable or sourceable `tests/test_*.sh` file in sorted shell-glob order. Test files source `tests/lib/assert.sh` and use helpers such as `assert_eq`, `assert_contains`, `assert_file_exists`, and `assert_exit_code` for readable failures. Every executable behavior change ships with a focused test that can run through `bash tests/run.sh` without external dependencies.

## Documentation

Documentation uses a professional, direct tone with no marketing language. Every user-facing behavior, command, environment variable, and failure mode must be documented close to the feature that introduces it.

## Commits

Commit subjects are imperative and no longer than 72 characters. Commit bodies explain why the change exists, especially for behavior, compatibility, or safety decisions.

## Work packets

Implementation arrives via reviewed packets; see [docs/build/orchestration.md](docs/build/orchestration.md).
