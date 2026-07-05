# Packaging Albion for distribution

Albion is developed as a repository (launcher in `bin/`, plugin in `plugin/`,
with `env/`, `charter/`, `config/`, and `state/` alongside). For distribution —
especially the Claude Code plugin marketplace — it is assembled into a single
**self-contained plugin directory** that carries both the plugin *and* the
launcher and everything the launcher needs.

## Build it

```bash
bin/albion-package               # writes ./dist/albion
bin/albion-package --out /path   # or a location you choose
```

The result is a directory that is simultaneously:

- a valid Claude Code plugin — `.claude-plugin/plugin.json`, `hooks/`, `scripts/`,
  `skills/`, `agents/` at its root; and
- a complete Albion install — `bin/` (the launcher + tools), `env/`, `charter/`
  (the compiled charter), `config/`, and `state/`. The manifest-dependent dev
  tools (`albion-compile`, `albion-package`) are deliberately omitted: a package
  ships the compiled charter without the `manifest/` source they require.

`albion-package` refuses to build if the charter is out of sync with `manifest/`
(run `bin/albion-compile` first), and it self-checks that the packaged launcher
resolves the plugin, settings, and charter from *inside* the package.

## How the tools find their files in both layouts

The launcher, doctor, and the state-using hooks resolve their dependencies
relative to their own location and work in either layout:

| | Dev / clone | Packaged plugin |
|---|---|---|
| Launcher | `bin/albion` at repo root | `bin/albion` inside the plugin |
| Plugin dir | `<repo>/plugin` | the package root itself (detected via `.claude-plugin/plugin.json`) |
| `state/` | sibling of `plugin/` (`<repo>/state`) | bundled at the package root |

So the same code ships to both, and the dev test-suite exercises the classic
layout while `test_package.sh` exercises the packaged one.

## Distribute it

- **Marketplace:** the packaged directory is published at
  [AmbitiousRealism2025/albion-marketplace](https://github.com/AmbitiousRealism2025/albion-marketplace)
  (`/plugin marketplace add AmbitiousRealism2025/albion-marketplace`, then
  `/plugin install albion@albion`). When enabled, Claude Code adds its `bin/`
  to `PATH`, so `albion` is available; the hooks stay inert in stock `claude`
  sessions (they gate on `ALBION_ACTIVE`, which only the `albion` launcher
  sets — see the README's coexistence section). On each release, rebuild with
  `bin/albion-package` and refresh the marketplace repo's `plugins/albion/`
  copy and manifest version.
- **Direct:** `claude --plugin-dir /path/to/dist/albion`, or run the bundled
  launcher `/path/to/dist/albion/bin/albion` directly.

## Verify a build

```bash
dist/albion/bin/albion-doctor --live   # health matrix from inside the package
```

The `manifest` check is expected to **SKIP** in a packaged plugin (it ships the
compiled charter without the `manifest/` source, so there is nothing to
re-compile-and-diff); everything else should pass.
