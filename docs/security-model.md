# Albion Security Model & Hook Threat Model

This document states plainly what Albion's enforcement hooks are — and, just as importantly, what they are **not**. It reflects an adversarial red-team of the hooks (see `docs/build/log/007-adversarial-hooks.md`). Honesty here is the point: a defense oversold is worse than one accurately scoped.

## The layered model

Albion defends in depth, and the layers are not equal in strength:

1. **`permissions-deny.json` (the hard floor).** Claude Code's permission system enforces deny rules in the client, independent of any prompt or model. This is the real security boundary for the patterns it lists (`rm -rf /`, `sudo rm`, `mkfs`, `dd of=/dev/*`, `curl | sh`, `chmod 777 /`, force-push to protected refs; plus Read/Write denies for `.env`, `**/secrets/**`, `*.pem`, `*.key`, `**/*credentials*`).
2. **The enforcement hooks (best-effort defense-in-depth).** The destructive-command guard, secrets scrubber, and Stop gate are **speed-bumps and backstops**, not security boundaries. They add coverage and catch honest mistakes and reward-hacking drift by a *semi-trusted model*. They are not designed to stop a determined adversary who already has arbitrary shell access — no denylist can, because a shell has infinitely many equivalent encodings of any command.
3. **Human and harness oversight.** Permission prompts, plan mode, and the maintainer remain the ultimate control.

**The threat Albion actually targets:** a capable but imperfect model (GLM-5.2) that may drift, hallucinate progress, or reach for a destructive shortcut — not a malicious operator. Read every hook guarantee in that light.

## Destructive-command guard (`pre-tool-guard.sh`)

**Does:** normalizes common obfuscations (URL-encoding, quote-splicing, `$'\xNN'`, case) and denies a curated table of catastrophic commands and their literal near-miss variants.

**Does not, by design:**
- Catch obfuscations that only resolve at shell runtime: `${IFS}` field-splitting, variable indirection (`a=rm; $a -rf /`), or runtime-supplied targets (`echo / | xargs rm -rf`). Enumerating these without heavy false positives is impossible for a denylist, and ALB-007 forbids heuristic "suspicious-looking" denials because false positives destroy trust.
- Cover every destructive operation. It targets filesystem-root removal and a named set of high-blast-radius commands; it is not an exhaustive catalog of every way to damage a system.
- Fail closed. Malformed input **allows** (and logs) — a guard that bricked every Bash call on a parser hiccup would be worse than the risk it mitigates.

The `permissions-deny.json` hard floor is the complementary control for the literal dangerous forms.

## Workbench secrets scrubber (`workbench-scrubber.sh`)

**Does:** redacts a registry of credential formats in files written under `.agent-workbench/`, after the write.

**Does not, by design:**
- Prevent the transient on-disk window. Redaction is post-write; a secret exists briefly before scrubbing, and a format outside the registry persists. The model already saw the content it wrote — the scrubber's job is to limit *persistence*, not to prevent disclosure. The complementary control is the Read/Write deny-list.
- Cover every credential format. The registry is extended over time; uncovered formats pass through.
- Act outside `.agent-workbench/` paths.

## Stop completion gate (`stop-gate.sh`)

**Does:** mechanically block premature session termination when objective state shows open tasks, a failed last test, or empty workbench verification — an anti-reward-hacking backstop over Albion's own recorded state.

**Does not, by design:**
- Resist tampering. `gate.blocks` and the task/test state live in the agent-writable workspace. An agent that would rewrite the counter could equally set `tasks.open=0`; the gate checks objective state, it is not a tamper-proof vault. (Relocating state outside agent-writable space is possible future work.)
- Trap a session. Loop-safety is paramount: a self-imposed 3-block ceiling yields below Claude Code's cap, and every error path fails open. This is verified and deliberate — the gate errs toward letting a session stop, never toward trapping it.
- Judge verification *quality*. It checks that `verification.md` is non-empty, not that its contents constitute real verification (that is the verifier agent's job).

## A note on the non-security hooks

The suite also contains hooks that are *functional*, not defensive, and make no security claims: the strike counter (progress signal), SessionStart re-injection (compaction survival), image-read interception (vision routing — its deny reason is scrubbed of env values whose names look credential-shaped), and the Stop gate's completion manifest (conductor signaling; contains paths, slugs, and states — never file contents).

## Reporting

Security issues in Albion itself should be reported per [`SECURITY.md`](../SECURITY.md). This document tracks the hook hardening backlog as items land.
