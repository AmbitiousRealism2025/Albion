# Contributing to Albion

Thanks for your interest. Albion is small, deliberate, and test-gated; contributions that match that shape merge quickly.

## Development setup

No dependencies beyond `bash`, `python3`, `curl`, and (for lint parity with CI) `shellcheck`. Clone and run:

```bash
bash tests/run.sh        # full suite — zero-dependency, hermetic, must stay green
```

Run the CI-equivalent shellcheck batch before pushing (single-file shellcheck raises false SC1091s; use the batch form from `.github/workflows/ci.yml`):

```bash
find bin env plugin/scripts state tests -type f -print0 |
  while IFS= read -r -d '' f; do
    if [[ "$f" == *.sh ]]; then printf '%s\0' "$f"; continue; fi
    if IFS= read -r first < "$f" && [[ "$first" =~ ^#!.*(bash|[[:space:]/]sh)([[:space:]]|$) ]]; then printf '%s\0' "$f"; fi
  done | xargs -0 -r shellcheck
```

## Rules that will save you a review round

- **Read [`CONVENTIONS.md`](CONVENTIONS.md) first.** Portability is enforced: identical behavior on macOS (BSD userland) and Ubuntu (GNU). Use `python3` for anything `sed`/`stat`-fragile. CI runs both platforms' expectations.
- **Tests assert invariants, not constants.** Derived output (counts, tallies) is computed in the test, not hardcoded — hardcoded constants have broken three times in this repo's history and are now a review flag.
- **Hooks and config are only "verified" when the consumer that loads them has been observed acting on them.** Schema-shaped tests are necessary, not sufficient — see [build log 012](docs/build/log/012-m4-sealed-and-the-hooks-that-never-fired.md) for the scar tissue.
- **Charter changes go through `manifest/`.** `charter/ALBION.md` is compiled; edit the fragments in `manifest/sections/` and run `bin/albion-compile`. The drift gate (`--check`) is CI-enforced.
- **No new dependencies.** The zero-dependency property is a deliberate distribution feature.

## How changes are reviewed

Albion is built by a conductor-and-workers process ([`docs/build/orchestration.md`](docs/build/orchestration.md)); external PRs get the same gate: scope check against the stated intent, full suite, shellcheck batch, and behavior probed directly rather than taken from the description. CI green is required for merge. Honest partial work with a clear description beats polished-looking claims — that principle is load-bearing here.

## Reporting bugs

Open a GitHub issue with the smallest reproduction you can manage. For anything security-relevant, use [`SECURITY.md`](SECURITY.md) instead of a public issue.
