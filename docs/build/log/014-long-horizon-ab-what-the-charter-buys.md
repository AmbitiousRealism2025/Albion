# Build Log 014 — Long-Horizon A/B: What the Charter Actually Buys

**Date:** 2026-07-04
**Type:** Diagnostic (not a milestone). Dogfooding Albion on a real long-horizon task to settle three open questions carried since M3: does the workbench tier ever engage; does forced compaction exercise the re-injection hook; and what, measurably, does the always-on charter add over the standalone `fable-mode` skill.

## Setup

- **Target:** a real, private ~350k-LOC TypeScript monorepo (referred to abstractly; no internals reproduced here). Strictly read-only analysis; the model ran from an isolated scratch cwd and read the repo via absolute paths. Repo verified byte-for-byte untouched before and after all four runs.
- **Task:** one identical prompt — "map the architecture and rank the top technical-debt/risks with file-level evidence" — genuinely open-ended and breadth-heavy.
- **Design:** 2 arms × 2 effort tiers = 4 runs. Arms: **Albion** (charter + plugin + hooks) vs **"vanilla"** (`albion --vanilla`). Compaction window force-lowered to 150k to try to trigger a compaction boundary.

## Finding 0 — the effort gap (fourth "specified but not enforced")

The first two runs executed at `effortLevel: high`, not the `xhigh`/GLM-max the design mandates (proposal §3: "the main agent always reasons at full depth"). Nothing in `bin/`, `env/`, or `plugin/` ever set it — sessions silently inherited the ambient `settings.json`. This joins the inert hooks (log 012), the never-written `last_test` (log 013), and the unused named-agent roster as the fourth headline feature specified but not delivered. **Fixed:** settings corrected to `xhigh`; new `albion-doctor` effort check WARNs on any shortfall (does not use the forbidden `CLAUDE_CODE_EFFORT_LEVEL` env override). Runs were then repeated at true max.

## Finding 1 — "vanilla" is not bare; the skill carries the discipline

The vanilla arm **autonomously loaded the standalone `fable-mode-glm-5-2` skill** (installed at user scope, available to any session). So this was really *skill-only* vs *full-stack*, not *bare* vs *full-stack*. And the skill delivered: mid-run the vanilla arm caught its own measurement bug — an all-zeros grep result it recognized as implausible, root-caused to a shell-quoting artifact, and **refused to report until it re-verified.** That is the anti-reward-hacking thesis demonstrated live, from the skill alone. **Methodology consequence:** the `--vanilla` control (here and in the M5 bench) is contaminated by the user-scope skill; a true bare baseline must disable it.

## Finding 2 — at high effort, charter ≈ skill; workbench never engaged

The two high-effort reports were peers (233 vs 219 lines, same top risks, both with verification appendices, comparable evidence density). **Neither arm created any `.agent-workbench/` files.** Both kept their main context lean by fanning out one sub-agent per subsystem, so neither approached the 150k boundary. The workbench tier did not engage — a fourth consecutive confirmation (M3/M4/M5/here).

## Finding 3 — at max effort, the charter buys convergence (first real value signal)

Turning effort to max exposed a difference the high tier hid:

| | Albion | Vanilla (skill-only) |
|---|---|---|
| Wall time | **15.3 min** | **33.1 min (2.2×)** |
| Task-tracking | TaskCreate×5, TaskUpdate×10 | none |
| Compaction | none | **1 (crossed 150k)** |
| Report | 304 lines, top risks | 370 lines, same top risks |

One causal chain: Albion's task-tracking gave it an explicit definition of "done" — it scoped the work, closed its checklist, and stopped. Vanilla, with the skill's *evidence* discipline but none of the charter's *scope-lock and stop-rule*, used the extra reasoning budget to keep exploring, sprawled past 150k, and compacted. **The charter's demonstrated value is convergence/efficiency at high reasoning budgets** — and it is invisible at lower budgets, because only max effort supplies enough rope to sprawl. This argues *against* fully slimming the charter toward the skill; the always-on task-tracking earns its place.

## Finding 4 — the compaction machinery is aimed at the wrong arm

The forced compaction fired — but in the **vanilla** arm, which has **no re-injection hook**. Albion's convergence means it never compacts, so its SessionStart re-injection hook has still never fired across four runs. And when vanilla *did* compact on native summary alone, its final report **retained the same top findings** (effect-dependency risk, provider-surface risk, security cluster all present). So:

> The charter *prevents* compaction (via convergence); it does not need to *survive* it (via re-injection). And when compaction happens anyway, native handling was adequate on this task.

This makes the re-injection hook look as vestigial as the workbench: both defend against a failure mode the charter's convergence prevents, in the one arm that lacks them.

## Implications for M6 and beyond

- **Keep** the always-on task-tracking — it is the one charter feature with a measured benefit (2.2× convergence at max effort).
- **Re-scope or retire** the external workbench and the SessionStart re-injection hook — four runs, zero workbench engagement, and native compaction sufficed where it occurred. A `--lite` charter (trivial via the compile pipeline) that drops the workbench/loop scaffolding but keeps the contract + intent gate + task-tracking is the natural next A/B.
- **Fix the bench methodology:** disable the user-scope skill for a true bare arm; and build tasks that stress what the enforcement layer is actually for — destructive-action safety, hidden-acceptance-gate reward-hacking, multi-session work — not read-only analysis, which exercises none of it.
- **Follow-up experiment:** to ever exercise Albion's re-injection hook, force it to compact despite convergence (much lower window, or a delegation-resistant task).

## Caveats

n = 1 per cell, one task, read-only analysis. Every claim above is a **hypothesis with evidence attached**, not a proven result; the convergence and vestigial-hook findings both warrant repeated-trials confirmation. The value of this run is that it converted vague "the workbench never engages" unease into specific, mechanistic, testable claims — and produced the first measured argument for the always-on charter.
