# ADR-0001: OpenCode Plugin Integration via Declarative Nix Modules

- **Status**: Accepted
- **Date**: 2026-08-28
- **Deciders**: Matthias (config owner), Sisyphus

## Context

OpenCode plugins (e.g. `oh-my-opencode-slim`, `oh-my-openagent`) ship with an
**interactive installer CLI** (`bunx <plugin>@latest install`) that performs a
series of filesystem/config mutations on first install. Running such installers
by hand breaks the Nix contract: a Nix configuration must be **declarative and
reproducible** — the system state is derived from the flake, not from
one-shot, side-effectful scripts executed outside of it.

The installer for `oh-my-opencode-slim` performs (analyzed from
`src/cli/install.ts` and config-manager sources):

| # | Installer step | Mechanism |
|---|----------------|-----------|
| 1 | Check OpenCode installed | `which opencode` / binary scan |
| 2 | Register plugin | appends to `~/.config/opencode/opencode.json` `plugin[]` |
| 3 | Add TUI version badge | appends plugin to `tui.json` `plugin[]` |
| 4 | Warm plugin cache | `bun install` into `~/.cache/opencode/packages/<pkg>@latest` |
| 5 | Disable default agents | sets `config.agent.explore.disable = true`, `agent.general.disable = true` |
| 6 | Enable LSP | sets `config.lsp = true` |
| 7 | Background subagents shell exports | appends `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`, `OPENCODE_ENABLE_EXA=1` to `~/.zshrc` |
| 8 | Install desktop companion (optional) | downloads binary, sets `companion` in config |
| 9 | Write lite config | generates `<configDir>/oh-my-opencode-slim.json` (`{preset, presets}` format) |
| 10 | Sync bundled skills | copies `src/skills/*` into profile `skills/` + writes `.oh-my-opencode-slim/skills-manifest.json` |
| 11 | Print next steps | auth login, models refresh |

Two further facts shaped the decision:

- **Profile directories are plural**: `~/.config/opencode/profiles/<name>/` is the
  real layout on this machine (personal, omo, conductor, default, oh-my). A
  config written to the singular `profile/<name>/` is read by nothing.
- **Actual plugin has a successor**: the harness in daily use is
  `oh-my-openagent` (schema `omo.schema.json`, config `oh-my-openagent.jsonc`),
  while `oh-my-opencode-slim` (schema `oh-my-opencode-slim.schema.json`, config
  `oh-my-opencode-slim.json` in `{preset, presets}` format) is the plugin kept
  in the `personal` profile with the OpenCode Zen Free preset.

## Decision

Convert the **mechanics of the installer** into a Home Manager Nix module per
plugin, exposed under the `programs.<pluginName>` option namespace. Each module
declares, as data, everything the installer would have done:

1. **Plugin registration** → `programs.opencode.settings.plugin = [...]`
   (merged into the nix-managed `opencode.json`, symlinked from the store).
2. **Default-agent disabling** → `programs.opencode.settings.agent.explore = { disable = true; }`
   and `agent.general = { disable = true; }`.
3. **LSP enable** → `programs.opencode.settings.lsp = true`.
4. **Background-subagents shell exports** → `home.sessionVariables` with
   `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true"`, `OPENCODE_ENABLE_EXA = "1"`.
   Home Manager writes these into the shell profile at activation — same effect
   as the installer appending to `~/.zshrc`, but derived from the flake.
5. **Lite config** → `xdg.configFile."opencode/profiles/<profile>/<plugin>.json"
   `.text = builtins.toJSON config`. The profile name is a module option
   (default `personal`). Note: a Home Manager module is a **singleton** — one
   module file declares one profile. Supporting N profiles requires either one
   module file per profile or a `profiles = [ ... ]` list option (future work;
   not yet implemented).
6. **Profile `opencode.jsonc`** → generated per profile with its plugin list.
7. **Runtime deps** (`bun`, `nodejs`) → `home.packages`.

### Known gaps at time of writing (post-hoc audit 2026-08-28)

The installer performs mutations that are **not yet converted** to a declarative
Nix equivalent. Recording them explicitly so they are not mistaken for done:

| Installer step | State | Gap |
|----------------|-------|-----|
| 3. TUI plugin registration (`tui.json`) | **CONVERTED 2026-08-28** | Both modules now generate `opencode/profiles/<profile>/tui.json` with the pinned plugin via the `tuiPlugins` option (default `[ "<plugin>@<version>" ]`). |
| 4. Plugin cache warm-up | **RUNTIME** | Plugin warms `~/.cache/opencode/packages/<pkg>@<version>` itself at load. Duplicating in Nix would fight the plugin's own cache-manager. |
| 8. Desktop companion binary | **FLAG ONLY** | `companion = false` is declared, but the binary itself is not installed. `installCompanion()` downloads a platform binary; a declarative equivalent would require packaging the binary as a Nix derivation. Credible only if the companion is desired and packaged. |
| 1. OpenCode-installed check | **OUT OF SCOPE** | A runtime sanity check, not state. Skipped by design. |
| 10. Bundled-skill sync | **RUNTIME** | Verified: 8 skills auto-synced into the profile `skills/` + `skills-manifest.json` by the plugin's `auto-update-checker` hook. |

**Version pinning**: all plugins in the top-level `settings.plugin` list plus the
two profile-level orchestration plugins are pinned in
`modules/opencode-plugin-versions.nix` (e.g. `oh-my-opencode-slim@2.2.17`,
`oh-my-openagent@4.19.4`, `@mohak34/opencode-notifier@0.2.8`, ...). Versions are
refreshed automatically by `make update` (`nix flake update` followed by
`scripts/update-opencode-plugin-versions.sh`, which queries the npm registry
`/latest` endpoint, handling scoped-package URL encoding) — so pins stay close
to the latest release without manual edits.

**Project-local config**: in addition to the profile config, the
`oh-my-opencode-slim` module also generates `.opencode/oh-my-opencode-slim.json`
(a project-local dev config). This was an implementation choice, not an
installer step.

### Guidance: installer → module conversion checklist

When integrating a new OpenCode plugin whose README says "run
`bunx <plugin> install`":

1. **Fetch and read the installer source** (or run with `--dry-run` if
   supported). Enumerate every filesystem/config mutation — not just the ones
   in the README.
2. For each mutation, find the **declarative Nix equivalent** (see mapping
   above). If none exists, add a module option that produces the equivalent
   file/setting.
3. **Never ship the installer as a generated script** to be run post-`switch`.
   That reintroduces the non-declarative state the ADR forbids.
4. **Verify the config schema** the plugin actually reads (check the plugin's
   `*.schema.json` / docs) — the earlier iteration invented a
   `{models, skills, mcpPermissions}` shape that the plugin ignores; the real
   format is the preset-based lite config.
5. **Respect profile paths** — plural `profiles/<name>/`, resolved per the
   plugin's `paths.ts` (`OPENCODE_CONFIG_DIR` → `XDG_CONFIG_HOME/opencode`).

### What remains out of Nix's scope (inherently interactive)

- **OAuth provider auth**: `opencode auth login` / `/connect` — requires
  browser/interactive input; cannot be declared.
- **Model catalogue refresh**: `opencode models --refresh` — pulls remote
  model lists at runtime.
- **Plugin cache warm-up** and **bundled-skill sync**: the plugin performs both
  itself at startup (verified: 8 skills auto-synced into the profile's
  `skills/` with a `skills-manifest.json`). Declaring these would duplicate
  runtime behavior and fight the plugin's own update checker.

## Consequences

### Positive

- System state fully reproducible from the flake; `make build && make switch`
  is the only install procedure.
- No stale post-install scripts to keep in sync with plugin releases.
- Profiles are first-class Nix data; renaming/addressing profiles is a one-line
  module option change.
- The mapping table above generalizes to any OpenCode plugin with an installer.

### Negative

- Plugin capability is capped at what can be expressed declaratively; installer
  steps with no Nix equivalent (e.g. an exotic binary download not in nixpkgs)
  require extra module work or a packaged derivation.
- The module needs to track plugin config-schema changes upstream (e.g. the
  `presets` shape) — schema drift is not caught by `nix flake check`.

### Risks

- **Secrets in profile configs**: the personal profile's `opencode.jsonc`
  contains MCP tokens (grafana). It is deliberately left user-managed (not
  nix-symlinked) to keep secrets out of the flake. Nix manages only the
  plugin-specific files that are secret-free.
- **Two orchestration plugins coexist** (`oh-my-opencode-slim` in `personal`,
  `oh-my-openagent` in `omo`). Keep their config files and plugin registrations
  strictly per-profile to avoid double-loading the harness.

## Implementation

- `modules/oh-my-opencode-slim.nix` — `personal` profile, OpenCode Zen Free
  preset (`opencode-zen-free-preset.md`).
- `modules/oh-my-openagent.nix` — `omo` profile, agent/category model map from
  `oh-my-openagent.jsonc`.
- Both imported in `home/agentic.nix`; shared env vars/settings merged via
  `lib.mkMerge` guarded by `lib.mkIf` option toggles.

### Verification

1. `make check` (`nix flake check`) — evaluates every darwin config, catches
   option-type errors and module schema mistakes.
2. `make build` — builds the full system closure; the home-manager diff then
   shows exactly which config files are added/removed (e.g. the
   `hm_opencodeprofiles*` entries) and confirms the store paths land in the
   expected `profiles/<name>/` locations.
3. `make switch` — applies. Interactive leftovers (`opencode auth login`,
   `opencode models --refresh`) are confirmed manually once per profile.