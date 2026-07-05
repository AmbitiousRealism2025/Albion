# Build Log 019 — Bench Process Metrics (Discriminating Bench, Phase 1)

**Date:** 2026-07-05
**Type:** Standard dispatched packet (ALB-029). **Conducted by Fable 5** —
verified at session start per the log-017 rule; no silent switch this session.

## Why this packet

The charter-trim question (maintainer call, 2026-07-05: no `--lite` product
mode; trim the *single* shipped charter, but only once the bench can
discriminate) was blocked on a measurement gap. Logs 014 and 018 established
that **outcomes do not discriminate** — at max effort both arms solve every
task — and that the charter's real, observed value is **process**: board
engagement, a complete evidence trail, recovery through compaction. Log 018
measured all of that by hand in interactive tmux sessions. The headless
harness recorded only a `workbench_present` boolean, so a lean-vs-full charter
A/B run through `bench/run-task` would have scored as a meaningless tie.

## What landed (`86c6daf`)

- **Run records bump to `albion-bench-run/v2`** with a `workbench` object:
  per-task artifact inventory (file names + byte sizes, sorted), `engaged`
  (same predicate as the retained `workbench_present`), `evidence_complete`
  (every board task dir has non-whitespace `task.md` **and** `verification.md`
  — deliberately the stop gate's open-task rule, inverted), and a lessons file
  count.
- **`bench/report` ingests v1 and v2 side by side.** New per-task `evidence`
  column and per-arm `evidence_complete_rate`, both scoped to records that
  carry the field — v1 records (the m5 report) render `n/a` and stay
  reproducible.
- Tests extended in `tests/test_bench.sh` (stub board writer; populated /
  bare / whitespace-only-verification cases asserted as exact objects) and
  `tests/test_bench_report.sh` (mixed v1+v2 ingestion, scoped denominators).
  `bench/README.md` documents the v2 schema.

## The cycle, honestly

- Dispatch was clean: one codex run, exit 0, scope exactly the five permitted
  files, no out-of-scope test touched. Full suite 28/28 and the CI-equivalent
  shellcheck batch verified by the conductor, not taken from the worker's
  report.
- The conductor's end-to-end probe showed the intended property directly: two
  stub runs, both `solved: true` (the null axis), while `workbench` diverged —
  `evidence_complete: true` with a 3-file inventory on the board arm, `engaged:
  false` on the bare arm — and the report rendered the discrimination in both
  tables.
- One process note for the record: the session's permission classifier
  declined the conductor's direct `git push` to `main` (the project's standing
  flow) pending explicit maintainer authorization, so this cycle ends with the
  commits local and the push queued for the maintainer. Not a defect — noted
  so the CI-green acceptance gate is visibly *pending*, not skipped: **CI has
  not yet run on this commit.**

## What this unblocks (phase 2)

The lean-charter experiment can now be scored: compile a lean charter variant
via `bin/albion-compile` (a throwaway experimental instrument, per the
maintainer's decision — not a shipped mode), run lean vs. full on the
long-horizon fixture (`revenue-pipeline`), and compare `evidence_complete_rate`
and the artifact inventories, not just `solved`. The compaction-recovery
ripcord remains an interactive-protocol measurement (log 018); it is out of
headless scope by design.
