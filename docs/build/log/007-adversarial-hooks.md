# Build Log 007 — Adversarial Red-Team of the Safety Hooks

**Date:** 2026-07-04
**Method:** a 4-agent workflow (3 independent hunters + 1 triage synthesizer), each running bypass attempts against the real hook scripts in sandboxes and recording actual output as evidence. This dogfoods Albion's own counterexample-hunter philosophy against Albion itself.

## Why this ran

The three hooks that guard against real harm — the destructive-command guard (ALB-007), the workbench secrets scrubber (ALB-010), and the Stop completion gate (ALB-009) — are exactly the code where a subtle miss is a genuine safety or security failure, and where mechanical unit tests only cover cases the *author* imagined. A red-team tests beyond that.

## Verdict: the approach paid off

The workflow reproduced every finding against the live scripts and separated signal from noise rigorously — it even **dropped several hunter over-claims** (e.g. "the hooks should fail *closed*"), correctly noting that fail-open is a deliberate, spec-mandated posture: ALB-007 forbids bricking every Bash call on a parser hiccup, and ALB-009 makes loop-safety paramount. Inverting the fail direction would reintroduce exactly what the specs forbid.

### Two genuine correctness defects (→ fix packets)

1. **[HIGH] Scrubber NotebookEdit target is dead.** `scoped_path()` reads `tool_input.file_path`, but NotebookEdit's real wire field is `notebook_path` (confirmed against the live tool schema). NotebookEdit is a declared, wired-in target — so it silently scrubs nothing, giving false assurance. → **ALB-010-R1.**
2. **[MEDIUM] Guard normalizer self-defeats on `\rm -rf /`.** An unconditional `printf '%b'` early in the pipeline interprets the leading `\r` as a carriage return, which `tr` collapses to a space, turning `rm` into ` m` — defeating the very backslash-strip meant to catch `r\m`. `\rm` is a catastrophic command and a common alias-bypass idiom. → **ALB-007-R1.**

### Cheap literal-form hardening folded into the reworks

The triage flagged a set of low-false-positive, literal-form extensions (not heuristics). Because this is a security tool aiming for OSS credibility, we harden what is cheaply hardenable rather than only documenting it:
- **Guard:** add `env|timeout|nohup|nice|setsid|stdbuf` to the wrapper alternation; backtick `eval` (not just `$()`); `git push origin +refspec` force-push; renamed fork bombs; broaden pipe-to-shell (sudo/tee/`|&` stages); add `/etc /home /usr /var` to recursive-removal targets and a `find … -delete` rule.
- **Scrubber:** add Google `AIza`, Stripe `sk_(live|test)_`, GitHub `github_pat_`, GitLab `glpat-`, and inline-credential DB URIs; fix the generic detector's `client_secret`/`api_secret` underscore miss and accept `:` (YAML) as a separator.
- **Stop gate:** case-insensitive/trimmed `last_test.status` with `failed`/`error` synonyms; coerce numeric-string and float `tasks.open` to a positive count. → **ALB-009-R1.**

### Inherent limitations (documented, not fixed) → `docs/security-model.md`

Denylists cannot enumerate a shell's infinite equivalent encodings (`${IFS}`, `$var` indirection, `xargs`-supplied targets). Fail-open is by design. The scrubber is a post-write persistence backstop. The `gate.blocks` counter lives in agent-writable state (an agent that could rewrite it could equally set `tasks.open=0` — the gate is an anti-reward-hacking backstop over objective state, not a tamper-proof vault). These are honestly disclosed with a "speed-bump, not a security boundary" caveat and the `permissions-deny.json` hard floor named as the complementary control.

### On the Stop gate's most important property

The dangerous direction for a completion gate is an **inescapable block**. The red-team confirmed the 3-block ceiling reliably yields and every error path fails open — the property ALB-009 cares most about held under attack. Its residual surface is consumer-side schema strictness (false-*negatives* over Albion's own state), which ALB-009-R1 normalizes.

## Metrics

| Metric | Value |
|---|---|
| Hunters / triage | 3 + 1 |
| Attempts executed with evidence | ~30 across three hooks |
| Genuine correctness defects | 2 |
| Cheap hardening items folded in | ~13 |
| Documented limitations | ~12 |
| False alarms / mis-severities corrected by triage | 3 |
| Workflow tokens (Claude side) | ~310k |

## Next

Three parallel rework packets (ALB-007-R1, ALB-009-R1, ALB-010-R1) → then ALB-012 wiring → M2 closeout.
