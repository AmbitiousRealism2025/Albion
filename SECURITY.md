# Security policy

## Report a vulnerability

Report security issues privately through
[GitHub Security Advisories](https://github.com/AmbitiousRealism2025/Albion/security/advisories/new),
not a public issue. Include the affected version, the smallest safe
reproduction, the impact, and any credential or path redactions you made.

This is a maintainer-run project. The maintainer will acknowledge a report when
capacity allows and will coordinate disclosure after the issue has been
assessed. Do not include live credentials in the report.

## Scope

Albion's enforcement hooks are checks around a semi-trusted model. They are not
a security boundary against a process with arbitrary shell access. The
[security model](docs/security-model.md) states the guarantee and limit of each
layer.

- Runtime shell indirection such as `${IFS}`, variables, and `xargs` pipelines
  can bypass the command guard. The guard does not claim to stop those forms.
- The stop gate and session state live in agent-writable space. The model can
  tamper with them.
- The secrets scrubber runs after a write and recognizes a finite registry of
  credential formats.

Please report gaps inside the stated guarantees. Examples include a credential
format that the registry claims to cover but misses, a hook that violates its
documented failure behavior, a secret that reaches hook output after the
redaction pass, or launcher and doctor output that exposes a token.

## Supported versions

Before 1.0, only current `main` receives fixes. A security fix may produce a new
tagged release, but older pre-1.0 tags do not receive backports unless a release
note says otherwise.
