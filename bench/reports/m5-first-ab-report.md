# Albion Bench Report

Runs directory: `/private/tmp/claude-501/-Users-ambrealismwork-Desktop-coding-projects-albion/2284184f-a483-4c2e-b6da-9a9b1b379b57/scratchpad/m5-ab-runs`
Run counts by arm: albion=6, vanilla=6
Lanes: plan
Date range: 2026-07-04T23:13:21Z to 2026-07-04T23:37:27Z

## Per-task Results

| task_id | arm | n | solved | wall_seconds_mean | turns_mean | cost_plan_prompt_equiv | gate_blocks | strikes | workbench |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| csv-dedup | albion | 1 | 1/1 | 214 | 14 | 0.778 | 0 | n/a | no |
| csv-dedup | vanilla | 1 | 1/1 | 164 | 13 | 0.722 | n/a | n/a | no |
| interval-merge | albion | 1 | 1/1 | 71 | 12 | 0.667 | 0 | n/a | no |
| interval-merge | vanilla | 1 | 1/1 | 78 | 12 | 0.667 | n/a | n/a | no |
| ledger-cache | albion | 1 | 1/1 | 161 | 14 | 0.778 | 0 | n/a | no |
| ledger-cache | vanilla | 1 | 1/1 | 123 | 14 | 0.778 | n/a | n/a | no |
| peak-window | albion | 1 | 1/1 | 144 | 16 | 0.889 | 0 | n/a | no |
| peak-window | vanilla | 1 | 1/1 | 107 | 7 | 0.389 | n/a | n/a | no |
| retry-policy | albion | 1 | 1/1 | 86 | 13 | 0.722 | 0 | n/a | no |
| retry-policy | vanilla | 1 | 1/1 | 83 | 12 | 0.667 | n/a | n/a | no |
| text-normalize | albion | 1 | 1/1 | 105 | 14 | 0.778 | 0 | n/a | no |
| text-normalize | vanilla | 1 | 1/1 | 124 | 17 | 0.944 | n/a | n/a | no |

## Aggregates Per Arm

| arm | n | solve_rate | wall_seconds_mean_solved | wall_seconds_median_solved | cost_plan_prompt_equiv_mean_solved | workbench_rate | gate_block_incidence | strike_incidence | last_test_fidelity |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| albion | 6 | 6/6 (100%) | 130.167 (n=6) | 124.5 (n=6) | 0.769 (n=6) | 0/6 (0%) | 0/6 (0%) | 0/6 (0%) | 5/6 (83.333%) |
| vanilla | 6 | 6/6 (100%) | 113.167 (n=6) | 115 (n=6) | 0.694 (n=6) | 0/6 (0%) | 0/6 (0%) | 0/6 (0%) | 0/6 (0%) |

## Honest Notes

Single-digit n supports direction, not statistical significance; no significance tests or confidence intervals are reported.

Task-arm cell counts:
- csv-dedup x albion: n=1
- csv-dedup x vanilla: n=1
- interval-merge x albion: n=1
- interval-merge x vanilla: n=1
- ledger-cache x albion: n=1
- ledger-cache x vanilla: n=1
- peak-window x albion: n=1
- peak-window x vanilla: n=1
- retry-policy x albion: n=1
- retry-policy x vanilla: n=1
- text-normalize x albion: n=1
- text-normalize x vanilla: n=1

Solved disagreements:
- none

Skipped records:
- none
