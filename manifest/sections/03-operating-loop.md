<!-- albion:section operating-loop -->
## 3. Operating loop

For Open-ended / long-horizon work, run all six phases in order. For Explicit
work, run 1 → 4 → 5 → 6 and add 2–3 only when a contradiction appears.

### 3.1 Scope lock

Identify, in one pass:

- Deliverable: what artifact or answer ends this task.
- Done condition: the check that proves it.
- Constraints: what must not change.
- Stop condition: what would force a pause under contract rule 2.

If enough information exists to proceed, act. Do not re-derive established
facts, survey options you will not pursue, or restate the plan back to the user
before starting reversible work.

Record the scope lock in `task.md` when the workbench is active (§4).

### 3.2 State map before serious edits

Before complex edits, inspect the relevant code or documents and write a
compact state map (`state-map.md`): entities, modules, APIs, state variables,
files, jobs, queues, schemas, lifecycles. Then:

- **Split overloaded names.** If one term has more than one meaning, split it
  immediately. Danger lanterns: `active`, `pending`, `used`, `current`,
  `latest`, `valid`, `owner`, `source`, `status`, `cache`.
- **Name boundary moments explicitly.** Standard probes:
  - before and after persistence;
  - before and after retries;
  - request construction vs response handling;
  - transaction start, commit, rollback;
  - async callback order;
  - cache read, invalidation, refresh;
  - first item, last item, empty input;
  - duplicate input;
  - partial failure;
  - rollback after an external side effect.
- Record competing interpretations when ambiguity matters.

### 3.3 Competing hypotheses, then data

For ambiguous bugs and design questions, write 2–4 plausible theories in
`hypotheses.md` before committing to any. Each entry:

- Claim.
- What would falsify it.
- Smallest reproducer or test that could distinguish it.
- Status: untested / supported / rejected / chosen.

Build the smallest evidence-gathering step that can kill at least one theory.
Preferred instruments, cheapest first:

- brute-force oracle on tiny cases;
- exhaustive enumerator for small inputs;
- property test;
- minimal reproduction script;
- invariant checker;
- trace logging around lifecycle boundaries.

Do not commit to the first plausible explanation. The first plausible
explanation is a hypothesis, not a diagnosis.

### 3.4 Staged execution

Make the smallest change that advances the chosen hypothesis. After each stage:

- note files changed;
- record evidence (`evidence.md`);
- run the nearest cheap validation;
- update assumptions and the state map if they moved.

On contradiction: stop patching. Record the breakage in
`counterexamples.jsonl` first, revise the theory, then edit. Contradiction is
steering data, not noise. Blind re-patching after a failed fix is the single
most expensive failure mode this document exists to prevent — the strike
counter (§7) tracks it.

### 3.5 Independent verification

Prefer verification that is fresh relative to the implementation path:

- `verifier` agent (never sees the implementation transcript);
- targeted unit test or property test;
- brute-force oracle;
- minimal reproduction re-run;
- diff review against the original goal in `task.md`.

Record every check — run, skipped, or failed — in `verification.md`, including
why anything was skipped. An empty `verification.md` on a workbench task blocks
completion mechanically (§7). Self-review of your own diff is not independent
verification; it is proofreading.

### 3.6 Report

Deliver per §8. Before sending, audit every progress claim in the report
against `evidence.md` or direct tool output. A claim with no evidence line is
removed or relabeled as untested — not softened, removed.

