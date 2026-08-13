# Contributing to Albion

Albion accepts focused changes with a clear failure case and a mechanical way
to check the result. Start by reading [`CONVENTIONS.md`](CONVENTIONS.md).

## Development setup

Required tools:

- `bash`
- `python3`
- `curl`
- `shellcheck` for the CI lint pass

Run the test suite from the repository root:

```bash
bash tests/run.sh
```

Run the same ShellCheck selection used by CI:

```bash
find bin env plugin/scripts state tests telemetry bench -type f -print0 |
  while IFS= read -r -d '' file; do
    if [[ "$file" == *.sh ]]; then
      printf '%s\0' "$file"
      continue
    fi

    if IFS= read -r first_line < "$file" &&
      [[ "$first_line" =~ ^#!.*(bash|[[:space:]/]sh)([[:space:]]|$) ]]; then
      printf '%s\0' "$file"
    fi
  done |
  xargs -0 -r shellcheck
```

The scripts target Ubuntu and macOS userlands. GitHub Actions currently runs
the Ubuntu checks. If a change depends on `sed`, `stat`, `date`, or another tool
that differs between GNU and BSD systems, test it on macOS or move the fragile
operation into `python3`.

## Change rules

- Add or update a test for changed behavior. Prefer an invariant over a copied
  output count.
- Verify hooks through the Claude Code consumer when possible. A valid JSON
  shape does not prove that Claude Code registered or executed the hook. The
  [hook registration postmortem](docs/build/log/012-m4-sealed-and-the-hooks-that-never-fired.md)
  explains why this rule exists.
- Edit charter source in `manifest/sections/`, then run `bin/albion-compile`.
  Do not edit `charter/ALBION.md` directly.
- Keep the runtime dependency set to `bash`, `python3`, and `curl` unless a
  change makes the distribution cost of a new dependency worth it.
- Never place a real credential in a fixture, log, screenshot, or issue.

## Documentation changes

Keep the README focused on installation, behavior, evidence, and limits. Put
implementation history in `docs/build/` and detailed command contracts beside
the command they describe.

Check relative links after moving or renaming a file. Claims about price,
provider quotas, model availability, and Claude Code behavior need a source or
a dated project measurement because they can change outside this repository.

## Pull requests

A useful pull request includes:

- the problem or failed invariant;
- the smallest relevant change;
- the command used to verify it;
- any live check that could not be run and why.

CI must pass before merge. Partial work is fine when the description names what
remains and does not claim a result that was not checked.

## Bug and security reports

Open a GitHub issue for ordinary bugs and include the smallest reproduction you
can provide. Use [`SECURITY.md`](SECURITY.md) for private security reports.
