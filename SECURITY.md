# Security Policy

## Reporting a vulnerability

Please report security issues privately via [GitHub Security Advisories](https://github.com/AmbitiousRealism2025/Albion/security/advisories/new) rather than a public issue. Reports are acknowledged as quickly as possible; this is a maintainer-run open-source project, so please allow a reasonable window before public disclosure.

## Scope — read this before reporting

Albion's enforcement hooks are **best-effort defense-in-depth over a semi-trusted model, not a security boundary against a determined adversary**. The honest threat model — what each layer does and deliberately does not defend — is documented in [`docs/security-model.md`](docs/security-model.md). In particular:

- Denylist bypasses via runtime shell obfuscation (`${IFS}`, variable indirection, `xargs` piping) are **known and documented non-goals** of the command guard; the `permissions-deny.json` hard floor is the boundary for literal dangerous forms.
- The Stop gate and session state live in agent-writable space by design; state-tampering by the very model being supervised is documented future work, not an undisclosed vulnerability.

Reports that identify gaps **within** the stated guarantees — a credential format the scrubber's registry claims to cover but misses, a hook that fails closed when it documents failing open, a secret leaking into hook output despite the redaction pass, launcher/doctor behavior that exposes a token — are exactly what this policy is for and are very welcome.

## Supported versions

Pre-1.0: only the current `main` is supported. From release 1.0 (milestone M6), tagged releases carry security support per the release notes.
