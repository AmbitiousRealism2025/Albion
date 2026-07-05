# Build Log 016 — Plugin Self-Containment (Marketplace-Ready)

**Date:** 2026-07-05
**Type:** Packaging / distribution. Makes the Albion plugin distributable as a single self-contained directory so a marketplace install carries the launcher, not just the plugin.

## The problem

The launcher (`bin/albion`) depends on files at the repo root — `env/`, `charter/`, `config/`, `state/`, and the `plugin/` subdirectory. A marketplace plugin, however, is a single directory whose root holds `.claude-plugin/plugin.json` and whose `bin/` goes on `PATH`. So "ship the launcher via the marketplace" required the plugin to be **self-contained**: everything the launcher needs, under one root — with the `state/` directory flipping from a *sibling* of the plugin (dev layout) to a *child* of it (packaged layout).

## The fix: layout-agnostic path resolution + a package script

Every tool that resolved a path as "two levels up from `scripts/`" or "`<repo>/plugin`" now works in **both** layouts, using its own location:

- **Launcher / doctor:** detect the plugin root as *self* when `.claude-plugin/plugin.json` sits beside the launcher (packaged), else `<repo>/plugin` (dev).
- **State-using hooks** (stop-gate, strikes, session-inject) and **verify-hooks:** find `state/state-lib.sh` / the plugin root by trying the packaged candidate first, then the dev candidate. This is backward-compatible by construction — the dev layout simply misses the first candidate and hits the second, so the whole existing suite stayed green with no test changes to the hooks.
- **Doctor manifest check:** SKIPs cleanly when there is no `manifest/` source (a packaged plugin ships the compiled charter only).

`bin/albion-package` assembles the distributable: it flattens `plugin/` to the output root and copies `bin/`, `env/`, `charter/ALBION.md`, `config/`, and `state/` alongside. It refuses to build a stale charter (gates on `albion-compile --check`) and self-verifies that the packaged launcher resolves plugin/settings/charter from inside the package.

## Verification

- **Dev suite unchanged and green** (28 files) — the candidate pattern didn't perturb existing behavior.
- **`test_package.sh`** builds a dist and asserts the structure, the launcher's self-resolution, and the packaged doctor's PASS/SKIP shape.
- **Live, end-to-end:** a real `albion` session launched *from the packaged dist* registered and fired its hooks — the Stop gate wrote a valid completion manifest. The packaged doctor reports 8 pass / 0 fail / 2 skip offline (manifest + fixtures skip, as designed).

## What is verified vs. what still needs the maintainer

The self-contained artifact is proven to work as a `--plugin-dir` target and as a standalone launcher. The one step that inherently needs the maintainer's account is the actual marketplace **publish** and the `/plugin install` round-trip — the packaging is ready for it, but that final hop can't be exercised from here. It is the last remaining piece of the M6 "marketplace entry" exit criterion.

## Coexistence note

Because the hooks gate on `ALBION_ACTIVE` (log: coexistence commit), the packaged plugin is safe to enable globally: it is inert in stock `claude` sessions and active only under the `albion` launcher. Self-containment and coexistence together make a one-install, no-interference marketplace product.
