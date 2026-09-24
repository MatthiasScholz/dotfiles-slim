# ADR-0005: OpenChamber CLI/Web via Nix, run as a declarative LaunchAgent

- **Status**: Accepted
- **Date**: 2026-09-24
- **Deciders**: Matthias (config owner), coding agent
- **Related**: ADR-0001 (installer → declarative module), ADR-0002 (state must
  live in the flake, not in tool-managed side channels), ADR-0004 (secrets via
  agenix)

## Context

[OpenChamber](https://github.com/openchamber/openchamber) is an "agentic
development environment" built on top of the OpenCode AI agent — a workspace to
start agent sessions, watch diffs, review, and drive work from desktop, web,
VS Code, or mobile. It is a *different thing* from OpenCode itself: OpenChamber
is the workspace/UI layer, OpenCode is the agent server it talks to.

Upstream distributes four surfaces, only one of which is a fit for this repo:

| Surface | Distribution | Nix-installable? |
|---|---|---|
| Desktop (macOS/Windows/Linux) | signed installers / DMG / AppImage on GitHub Releases | No (signed binary installers; also bundles its own OpenCode) |
| VS Code extension | Visual Studio Marketplace | No (marketplace-managed) |
| iOS / Android | App Store / Play | No |
| **CLI / Web server** | **npm package `@openchamber/web`** (`bin: openchamber`) | **Yes** |

Two upstream behaviours conflict with the contract this repo is built on (see
ADR-0001/0002: *the flake is the source of truth; imperative installers are
converted, not executed*):

1. **The install path is a shell installer.** `scripts/install.sh` checks for
   Node ≥ 22, picks a global package manager (`pnpm`/`yarn`/`bun`/`npm`) and
   runs `<pm> add -g @openchamber/web`. The result depends on which manager
   happens to be on `PATH` and mutates a global prefix outside Nix.
2. **"Run at login" is `openchamber startup enable`.** Upstream writes a
   LaunchAgent (`dev.openchamber.web`) to `~/Library/LaunchAgents`, a wrapper
   to `~/.config/openchamber/bin/OpenChamber`, and an **environment snapshot**
   (`~/.config/openchamber/startup.env`, mode 0600) of the invoking shell
   (`PATH`, provider tokens, SSH agent variables, …). The service is only
   reproducible as long as that snapshot file survives.

A third fact shaped the packaging: the published tarball is *already built*.
It contains the compiled frontend (`dist/`) and server (`server/`), and none of
the tree needs a compiler on the host:

- `node-pty` — the terminal backend — ships prebuilt binaries
  (`prebuilds/darwin-arm64/pty.node`, `darwin-x64`, `linux-arm64`, `linux-x64`)
  and its install script merely *verifies* that a prebuild exists
  (`scripts/prebuild.js || node-gyp rebuild`);
- `sherpa-onnx-node` (dictation) pulls its native addon from platform-specific
  optional packages (`sherpa-onnx-darwin-{arm64,x64}`, `linux-*`);
- `bun-pty` is only loaded when the server runs under Bun, not Node.

There is no build step to reproduce.

Requirement: install OpenChamber's CLI/Web server from the flake, have it
running under `launchctl` after `make switch`, and keep secrets and
configuration out of tool-managed side channels.

## Decision

**Package the published `@openchamber/web` npm artifact as a Nix derivation and
expose it through a `programs.openchamber` Home Manager module whose
LaunchAgent is declared in Nix — not created by `openchamber startup enable`.**

Concretely:

1. **Package the artifact, not the source.** `packages/openchamber/` holds a
   minimal `package.json` + `package-lock.json` (the only job of which is to
   pin the dependency tree) and a `buildNpmPackage` derivation with
   `dontNpmBuild = true`. The npm tarball already contains `dist/` + `server/`,
   so the derivation only resolves and installs dependencies.
2. **Version comes from the lockfile.** `version = lock.packages."node_modules/@openchamber/web".version`
   — the derivation cannot report a version different from the tree that
   `npmDepsHash` was computed for. Bumping is
   `npm install @openchamber/web@<v>` + refresh `npmDepsHash`.
3. **No compiler required.** `node-pty`'s `npm rebuild` finds a prebuilt for
   the host and never reaches `node-gyp`; `sherpa-onnx-node` resolves its
   native addon from platform optional packages. No C/C++ toolchain or
   `buildInputs` are needed. (Verified by a clean `nix build`.)
4. **The LaunchAgent is a Nix-declared `launchd.agents.openchamber`**
   (`serve --foreground`, `RunAtLoad`, `KeepAlive`, `ProcessType = Background`,
   `WorkingDirectory = $HOME`, logs in `~/Library/Logs/OpenChamber/`). Upstream's
   environment snapshot is replaced by:
   - an explicit `PATH` (Nix profiles + Homebrew + system) and `HOME`,
   - `OPENCODE_BINARY` pointing at `programs.opencode.package`,
   - the `environment` option for anything else the snapshot would have
     captured.
5. **One service writer.** `openchamber startup enable` is *not* used. If it
   was ever run by hand, `openchamber startup disable` must be run once so the
   upstream `dev.openchamber.web` agent and the Nix-managed
   `org.nix-community.home.openchamber` agent do not fight over the port.
6. **Secrets never enter the store or the plist.** For a network-exposed
   (`--host 0.0.0.0`) headless server, the UI password is provided through
   `uiPasswordFile` (an agenix-decrypted path per ADR-0004). launchd cannot
   expand files into `EnvironmentVariables`, so the module generates a small
   wrapper that reads the file at service start and `exec`s the binary. Only
   the *path* is written to the store.
7. **Fail early on unsafe exposure.** Binding to a non-loopback host without a
   password fails `nix flake check` with an assertion — mirroring upstream's
   own runtime refusal (`OPENCHAMBER_ALLOW_UNAUTHENTICATED_LAN=true` is the
   explicit escape hatch, closed by default).
8. **OpenChamber's own lifecycle commands are out of scope.** `openchamber
   update` would replace the Nix-managed install; `openchamber startup
   enable/disable` would create a second service writer. Nix owns both. The
   runtime commands (`status`, `logs`, `restart`, `stop`, `connect-url`,
   `tunnel`) remain available and work against the Nix-managed service.

### State sync-back (`preferences.json`)

OpenChamber splits its settings across two files: `settings.json` holds
*instance* facts (and secrets — relay/tunnel keys, the UI password, ssh hosts)
while `preferences.json` holds the user's *profile* (the `profile`-scoped keys
of its settings registry: themes, models, notifications, appearance, …). Only
the latter is user configuration, and only the latter is version-controlled
(`config/openchamber/preferences.json`, installed by `configFile` to
`~/.config/openchamber/preferences.json`).

The app rewrites that file on every settings change (atomic tmp+rename, which
replaces the Home Manager symlink with a regular file), so the next switch would
clobber it — exactly the ADR-0003 situation. `make sync-config-openchamber`
copies the live file back (keys sorted for a readable diff, secret-looking keys
refused), prints `git diff HEAD`, and leaves accept/reject to the user.
Device-scoped keys never reach either file, so no per-device state is captured.

## Module surface

| Option | Default | Purpose |
|---|---|---|
| `programs.openchamber.enable` | `false` | install the CLI/Web package |
| `programs.openchamber.package` | local derivation | override the package |
| `programs.openchamber.port` / `host` | `3000` / `127.0.0.1` | bind address |
| `programs.openchamber.apiOnly` | `false` | headless (`--api-only`) for desktop/mobile clients |
| `programs.openchamber.uiPasswordFile` | `null` | password file read by the LaunchAgent |
| `programs.openchamber.dataDir` | `null` (`~/.config/openchamber`) | state directory |
| `programs.openchamber.environment` | `{}` | env for session + service; also how `OPENCODE_HOST` / `OPENCODE_SKIP_START` are set |
| `programs.openchamber.extraArgs` | `[]` | extra `serve` arguments |
| `programs.openchamber.launchd.enable` | `false` | install + load the LaunchAgent |

## OpenCode coupling

OpenChamber's server startup order is: reuse a server it started → connect to a
configured external one → auto-detect one on `:4096` → otherwise start and
supervise its own. This repo already installs OpenCode declaratively
(`programs.opencode`), so the module:

- exports `OPENCODE_BINARY = lib.getExe config.programs.opencode.package`
  (the CLI reads `OPENCODE_BINARY` first; `OPENCODE_PATH` /
  `OPENCHAMBER_OPENCODE_BIN` are accepted fallbacks) — essential, because the
  LaunchAgent's `PATH` is not the login shell's;
- makes switching to an externally-run OpenCode a two-line config change
  (`environment.OPENCODE_HOST`, `environment.OPENCODE_SKIP_START`), which is
  upstream's documented flow.

## Architecture (files touched)

- `packages/openchamber/default.nix` — `buildNpmPackage` derivation over the
  published tarball (`dontNpmBuild`, lockfile-derived version, `postInstall`
  symlink of the nested `bin/cli.js` to `$out/bin/openchamber`)
- `packages/openchamber/package.json` + `package-lock.json` — pinned dependency
  manifest/lockfile (all platform optionals recorded)
- `modules/openchamber.nix` — `programs.openchamber` HM module: package,
  session env, assertion, LaunchAgent, password wrapper, log-dir activation,
  `configFile`
- `config/openchamber/preferences.json` — version-controlled profile settings
  (source of truth)
- `scripts/sync-config-openchamber.sh` + `make sync-config-openchamber` —
  copy-back + `git diff` review
- `home/agentic.nix` — imports the module and enables it with
  `launchd.enable = true`, `host = "0.0.0.0"` and the agenix-backed
  `uiPasswordFile` (LAN exposure)
- `secrets/openchamber-web.age` — agenix-encrypted UI password (ADR-0004)
- `docs/adr/0005-…` — this document

## Verification

1. `nix build` of the package: builds without a compiler; `openchamber
   --version` → `2.0.0`; `openchamber serve --foreground` responds `HTTP 200`
   on the health endpoint and starts its OpenCode child.
2. `nix eval … .launchd.agents.openchamber` — program arguments, environment
   (`HOME`, `PATH`, `OPENCODE_BINARY`, `OPENCHAMBER_PORT/HOST`), working
   directory and log paths as intended.
3. Password path: with `uiPasswordFile` set and `host = "0.0.0.0"`, the
   program argument is the generated wrapper; the wrapper builds and contains
   only the secret path.
4. Unsafe-exposure assertion: `extendModules` override to `host = "0.0.0.0"`
   without a password fails evaluation of the darwin toplevel with a readable
   message.
5. `nix flake check --no-build` → `✅ darwinConfigurations.Matthiass-MacBook-Pro`.
   (The `MacPro` x86_64-darwin config fails on a pre-existing
   `targets.darwin.defaults` assertion, unrelated to this change — verified
   against a clean `HEAD` worktree.)
6. Sync-back: `make sync-config-openchamber` shows the `git diff HEAD` of the
   synced file (the new file on first run, modifications afterwards) and reports
   "no changes" when the live settings already match the committed file.

## Consequences

### Positive

- Installed, pinned and reproducible from the flake: `make switch` is the whole
  install procedure; no global package manager prefix involved.
- One service writer; the LaunchAgent is reviewable Nix and survives rebuilds.
- Secrets stay in agenix (ADR-0004) and never touch the store or the plist.
- Unsafe network exposure is caught at evaluation time rather than at runtime.
- The npm tarball approach sidesteps building the upstream monorepo (bun +
  Vite + Rust terminal backends) from source.

### Negative

- The derivation tracks the published npm tarball, so a version bump is a
  two-file dance with a hash refresh (`npm install` + `npmDepsHash`) rather
  than a flake input bump.
- `npmDepsHash` is lockfile-sensitive: any edit to
  `packages/openchamber/package-lock.json` invalidates it.
- The module must keep pace with upstream's flags/env vars (`--api-only`,
  `OPENCODE_BINARY`, the exposure check) — schema drift is not caught by
  `nix flake check`.
- The upstream environment snapshot is deliberately *not* reproduced.
  Variables that the snapshot would have carried (provider tokens, dynamic
  `SSH_AUTH_SOCK`, `BUN_INSTALL`, …) must be added to `environment` or relied
  on from the launchd session. macOS LaunchAgents in the `gui` domain do
  inherit the session's `SSH_AUTH_SOCK`, which covers the common case.
- `openchamber update` is a footgun: it would replace the Nix-managed install
  in place. It is not wired anywhere, but nothing prevents a user from
  running it.

### Risks

- **Port / service conflict** with a previously hand-installed
  `dev.openchamber.web` agent or a manually daemonised `openchamber` (running
  `openchamber` in a terminal daemonises and binds the same port). While one is
  running, the LaunchAgent exits 1 and launchd restarts it in a loop
  (`Error: OpenChamber is already running on port ...` in
  `~/Library/Logs/OpenChamber/startup.err.log`). Remedy: `openchamber startup
  disable` for the old agent, or `openchamber stop --port <port>` for a stray
  daemon — launchd starts the service within its throttle interval afterwards.
  This was the first real failure hit during rollout.
- **`KeepAlive = true` restart loop** if the server exits deterministically
  (e.g. a conflicting instance). launchd throttles restarts (10 s default),
  so the failure is noisy but not a fork bomb.
- **Headless + `0.0.0.0`** is only as safe as the agenix secret file. The
  assertion removes the "forgot the password" failure mode, not a weak
  password.
- **agenix / LaunchAgent start order**: the password is decrypted by agenix's
  own `activate-agenix` LaunchAgent at login, so the openchamber wrapper waits
  (bounded, 60 s) for `uiPasswordFile` to become readable before starting. If
  it never appears, the LAN bind is refused by upstream and launchd restarts
  the job.
- **`preferences.json` UI edits are lost unless synced first**: the app
  re-materializes the full profile on its next settings write, so a pruned
  declarative file does not stay pruned; the loop is copy-and-review
  (ADR-0003), not a partial merge.
- **Data directory is unmanaged** (`~/.config/openchamber`): settings, tunnel
  profiles and a `startup.env` written by the app are user-managed state, in
  the same spirit as ADR-0003's decision not to fight a daemon over its own
  config file.

## Alternatives considered (and rejected)

| Alternative | Reason rejected |
|---|---|
| `curl … install.sh \| bash` post-`switch` activation hook | Reintroduces the non-declarative, manager-dependent install ADR-0001 forbids; global prefix outside Nix; version unpinned |
| Build `@openchamber/web` from the upstream monorepo source (bun + Vite) | Heavy toolchain (bun, Vite, Rust `bun-pty`/`sherpa-onnx`), needs network at build time for the extension build; the published artifact is already built and cheaper to reproduce |
| Homebrew cask for the OpenChamber **desktop** app | Desktop bundles its own OpenCode, is a signed installer (unfree/unsigned quirks), and duplicates the CLI/Web surface; out of scope for a headless workstation integration |
| Use `openchamber startup enable` inside an activation script | Creates a second, imperative service writer and a mutable env snapshot; violates ADR-0002's "state must live in the flake" |
| Point the LaunchAgent at the npm global prefix created by `npm install -g` | Same as the install-script option: unpinned, manager-dependent, outside the store |
| Put the UI password directly in `environment`/plist | Secret lands in the world-readable Nix store and in `~/Library/LaunchAgents/*.plist`; conflicts with ADR-0004 |
| `--api-only` + `--lan` unconditionally | Removes the browser UI that is the main reason to run the server locally, and exposes it; both are opt-in instead |

## References

- OpenChamber: <https://github.com/openchamber/openchamber>
- OpenCode server docs (detection order, `OPENCODE_HOST`, `OPENCODE_SKIP_START`,
  `startup enable`, `--api-only`): <https://docs.openchamber.dev/opencode-server/>
- npm package: <https://www.npmjs.com/package/@openchamber/web>
- OpenCode: <https://opencode.ai>
- Module: `modules/openchamber.nix`; package: `packages/openchamber/`;
  enablement: `home/agentic.nix`
- Related ADRs: ADR-0001 (installer → module), ADR-0002 (state in the flake),
  ADR-0004 (agenix for the UI password file)
