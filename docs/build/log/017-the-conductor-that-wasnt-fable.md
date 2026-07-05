# Build Log 017 — The Conductor That Wasn't Fable (and the Audit That Followed)

**Date:** 2026-07-05
**Type:** Postmortem + full audit of the affected range. This entry corrects the build record itself.

## What happened

This project's methodology names **Claude Fable 5** as the conductor, and the
commit trailers from M4 onward say so. The transcript says otherwise. At
**2026-07-04T22:39:02Z** — the M3→M4 boundary, minutes before the maintainer
authorized the overnight autonomous run — the conductor session was silently
switched by a `model_refusal_fallback` event:

> *"Fable 5's safeguards flagged this message. The safeguards are intentionally
> broad right now and may flag safe and routine coding, cybersecurity, or
> biology work… Switched to Opus 4.8."*

The same mechanism had already bounced M2 to Opus (recorded honestly at the
time). This second fallback stuck and went unnoticed for ~15.5 hours because it
surfaced only as a transient warning line — and because the conductor (me)
never checked its own model against the trailers it was stamping. Everything
from M4 through M6, the coexistence/self-containment batch, and the first
board-stressing bench work was conducted by **Opus 4.8** while the record said
Fable 5.

**The corrected conductor history** (from per-turn transcript forensics, not
memory): M0–M1 Fable → M2 Opus (safeguard fallback, known) → M3 Fable →
**M4 onward Opus (safeguard fallback, silent)**. Detection was evidence-based:
per-turn `model` fields in the session transcripts, with the fallback event as
the smoking gun.

## Why it matters here specifically

Albion *is* security tooling — guard hooks, a threat model, credential
handling, reward-hack defenses. That is exactly the material Fable's
intentionally-broad safeguard flags. **A Fable-conducted build of a security
project keeps tripping its conductor's own safeguard**, and the fallback is
easy to miss. This is a real constraint on "Fable as orchestrator"
demonstrations for this class of project, and worth knowing for anyone
attempting one.

**Mitigation now in place:** the maintainer's statusline renders the live
session model (read per-turn from the harness, not hardcoded), so a silent
fallback is visible the moment it happens.

## The audit of the affected range (eb2318f..HEAD, 23 commits)

The maintainer switched the session back to Fable 5 and ordered a full review.
Method: mechanical gates, then **three parallel fresh-context reviewers** (none
given the author's narrative — the work under review was authored by the same
session doing the audit, so self-review was disqualified), everything probed
live rather than read.

**Verdict: directionally sound.** Suite/CI/shellcheck/doctor all green;
credential handling **clean** (hostile-input tokens, mode-600 enforcement, mask
bypass attempts — no leaks); every enforcement chain traced end-to-end and
sound; the ALB-026 discrimination proof and self-containment claims reproduced
from scratch; `--settings effortLevel` proven honored by live probe (config-dir
poisoned to `low`, session ran `xhigh`).

**Findings (all fixed in the commit preceding this entry):**

1. **The deny floor was documented but never delivered** — `security-model.md`
   called `permissions-deny.json` "the hard floor… the real security boundary,"
   and no code path ever loaded it. An **M2 (Fable-era) gap**, i.e. the audit's
   biggest finding predates the mislabeled range — but the Opus-era coexistence
   work built the exact `--settings` delivery mechanism and didn't connect it.
   Now wired, sync-tested against the stock fragment, and **live-verified**: a
   real session's `rm -rf` was denied at the permission layer, canary intact —
   and GLM, per charter §7, explicitly declined to obfuscate around the guard.
2. `albion --vanilla` claimed "bare" but still auto-loaded user-scope skills
   (the log-014 contamination). The launcher now appends
   `--disable-slash-commands`; the bench inherits it.
3. The packaged dist shipped two silently-broken manifest-dependent dev tools
   and a `.DS_Store`. Excluded.
4. Doc corrections: log-015's suite count misstated (12→ corrected to 22, noted
   inline); stale corpus count in the handoff. Counts accurate-when-written
   (e.g. "four tools" before `albion-setup` existed) were left untouched —
   historical entries are not silently rewritten.
5. One test asserted a constant ("README is five lines") rather than its
   invariant (compact + names the wired copy) — converted, per the standing
   assert-invariants rule from log 010.

## Attribution policy going forward

Historical commits are **not** rewritten (no force-push to fix trailers; the
public history stands, corrected by this entry). The convention remains
"trailer = the tier actually running," now verified per-session against the
statusline rather than assumed from the handoff. This entry is the durable
correction: **M4–M6 and the post-M6 batch were conducted by Opus 4.8.** The
charter itself — Albion's core — was authored by Fable 5 in M3 and is
unaffected.

## Lessons

- **A silent model fallback is a record-integrity hazard.** If the conductor's
  identity matters to the record, verify it from ground truth every session —
  it was sitting in the environment block the whole time, unread.
- The audit pattern that worked: fresh-context reviewers with adversarial
  lenses + live probes. It caught a documented-but-inert security boundary that
  every prior layer (including an adversarial red-team of the hooks themselves)
  had missed, because everyone reviewed the *hooks* and nobody traced the
  *delivery* of the settings fragment.
- The inert-feature class now has four instances (hooks.json array-form,
  unwritten `last_test`, unset effort default, unwired deny floor). Every one
  was "specified, documented, tested at the file level — never delivered."
  The registration lesson generalizes: **test the delivery, not the artifact.**
