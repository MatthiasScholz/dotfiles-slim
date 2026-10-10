# ADR-0008: OpenChamber desktop app as a client of the Nix-managed server

- **Status**: Accepted
- **Date**: 2026-10-08
- **Deciders**: Matthias (config owner), coding agent
- **Related**: ADR-0005 (packaged the CLI/Web server and its declarative
  LaunchAgent; **supersedes its rejection of the desktop cask for this use
  case**), ADR-0004 (agenix owns the UI password), ADR-0002 (state must live in
  the flake, not tool-managed side channels), ADR-0001 (imperative installers
  are converted, not executed)

## Context

ADR-0005 packaged only the *CLI/Web server* surface of OpenChamber as the
`programs.openchamber` Home Manager module and runs it as a Nix-declared
LaunchAgent. It explicitly rejected the **desktop app** — a signed Electron
bundle distributed as DMG/zip/AppImage/NSIS installers — as out of scope for a
reproducible, headless workstation integration. At the time the desktop app and
the server were treated as mutually exclusive choices.

They are not. This ADR records the decision to run **both on one machine**,
with the desktop app as a *client* of the Nix-managed server rather than as a
second, independent server. The reasoning rests on source inspection of
upstream `v2.2.0` (`packages/electron/main.mjs`, `packages/web/server/index.js`)
rather than on documented behaviour:

### What the desktop app actually is

| Fact | Source |
|---|---|
| Electron app, MIT-licensed, source at `packages/electron` | `openchamber/openchamber` repo |
| Signed installers on GitHub Releases; frozen as Homebrew cask `openchamber` (`auto_updates: true`, macOS ≥ 12) | `homebrew/cask` |
| Default server port **57123** (`DEFAULT_DESKTOP_PORT`), or `settings.desktopLocalPort`, else a free port | `main.mjs` |
| A distinct process with its own Electron single-instance lock; the module's LaunchAgent is a plain `node` process | `entry.mjs` |
| **Data root is `~/.config/openchamber`** unless `OPENCHAMBER_DATA_DIR` is set; the desktop does **not** relocate it | `web/server/index.js` (`OPENCHAMBER_USER_CONFIG_ROOT`), `early-startup.mjs` (`settingsFilePath`) |
| Can run as a pure client of an external server: `OPENCHAMBER_SKIP_LOCAL_SERVER=1` + `OPENCHAMBER_SERVER_URL=<url>` loads its bundled UI and points the API at that URL | `main.mjs` `resolveInitialUrl` |
| Inherits the login shell's environment through its own probe (`inheritUserShellEnv`), so Home Manager `sessionVariables` reach it | `main.mjs`, `shell-environment.mjs` |

### The collision surface (measured, not assumed)

- **Ports do not collide.** The desktop defaults to 57123; the module uses 3000.
- **Processes do not collide.** Separate single-instance domains.
- **The data directory *is* shared.** Both processes read/write
  `~/.config/openchamber`: `settings.json` (instance state and secrets,
  including both server keys and desktop-only keys such as `desktopHosts` and
  `desktopWindowState`), `preferences.json`, `projects/`, `themes/`, `chats/`,
  `relay-host.lock`, `push-subscriptions.json`, `remote-clients.json`.
  Upstream writes atomically (tmp + rename) and explicitly tolerates a
  concurrent writer (`readJsonFile` in `early-startup.mjs` logs and retries the
  read), but a lost-update race between two live servers is still possible.
- **OpenCode is the shared agent runtime.** `programs.opencode.web` already
  binds `0.0.0.0:4096`; OpenChamber's startup order is *reuse → configured
  external → auto-detect :4096 → start own*, so both surfaces should converge
  on that one server, but only if it is pinned explicitly.

Running two independent servers (module + desktop embedded) is therefore
*possible* — and kept as a fallback — but it makes two processes co-own one
data directory and, if LAN access is enabled, register two relay/pairing
identities. The cleaner combination is one server, many clients — which is
upstream's own multi-surface design ("open the same sessions from Desktop, Web,
VS Code, iOS, Android").

## Decision

**Install the desktop app through the existing nix-homebrew cask mechanism and
run it as a client of the module's LaunchAgent server.**

1. **Cask, not packaging.** Add `"openchamber"` to the `casks` list in
   `darwin/homebrew.nix`. ADR-0005's rejection of the cask is superseded *for
   this use case*: code signing, notarization and the Electron self-updater stay
   upstream, in exchange for the desktop binary **not** being flake-reproducible
   (Homebrew owns the version, `auto_updates: true` means it drifts).
2. **Client mode.** The module gains `programs.openchamber.desktopClient`. When
   enabled it exports two **session variables** —
   `OPENCHAMBER_SKIP_LOCAL_SERVER=1` and `OPENCHAMBER_SERVER_URL=http://<host>:<port>`
   — which the desktop app's login-shell probe inherits, so it loads its bundled
   UI and attaches to the module's server instead of starting its own. They are
   session-only: the LaunchAgent never sees desktop-client flags.
3. **One OpenCode.** Set `programs.openchamber.environment.OPENCODE_HOST =
   "http://localhost:4096"` and `OPENCODE_SKIP_START = "true"` in
   `home/agentic.nix` so the module's server attaches to `programs.opencode.web`
   deterministically instead of relying on auto-detection (ADR-0005's documented
   flow). The desktop client then inherits that same agent runtime for free.
4. **Opt-out is explicit.** Setting `desktopClient.enable = false` (or removing
   the cask) returns the desktop to its embedded server on 57123; that mode
   still works but is the fallback described above.
5. **Version sync.** The desktop app and the server are the same product and
   must share a version: the desktop is a client of the server. The cask version
   is owned by the pinned `homebrew-cask` flake input (advanced by
   `make update`); the server version by
   `packages/openchamber/package-lock.json`. `darwin/openchamber.nix` reads both and
   emits a warning when they differ, so the two are bumped together rather than
   silently drifting. Today both are `2.2.0`.

## Consequences

### Positive

- **One server owns the port and the data directory.** Desktop, Web/PWA, VS
  Code and mobile all read the same sessions, projects and settings because the
  desktop is a client, not a second writer.
- **Desktop-specific risk stays upstream.** Signing, notarization, quarantine
  and self-update are Homebrew's/upstream's problem, handled by machinery this
  repo already runs.
- **Declarative intent.** The Nix config says "the desktop attaches here"; no
  hand-managed `desktopHosts` entry in runtime `settings.json`.
- **OpenCode stays single.** The `:4096` server that `programs.opencode`
  already runs is the only agent runtime.

### Negative

- **The desktop is not reproducible from the flake.** Its version is whatever
  Homebrew resolves; `auto_updates: true` means it can change without a commit.
  This is inherent to the cask and is the price of not packaging Electron.
- **Two version sources.** The cask version comes from the `homebrew-cask`
  flake input, the server version from the npm lockfile. `darwin/openchamber.nix`
  warns on drift, but nothing forces the two bumps into one commit — a
  `make update` that advances the tap past the packaged server is a warning, not
  an error.
- **Hard dependency on the LaunchAgent.** In client mode the desktop has no
  local fallback (`OPENCHAMBER_SKIP_LOCAL_SERVER=1` makes `localUrl` null); if
  the server is down — or agenix has not yet decrypted the UI password at login
  — the desktop shows a connection error until the service is up.
- **Two writers, one `settings.json`.** Even in client mode the desktop writes
  its own keys (window state, `desktopHosts`, desktop preferences) into the
  shared file. Writes are atomic and the key sets are largely disjoint, but a
  concurrent write can still drop an update. `preferences.json` remains the
  ADR-0003/ADR-0005 copy-and-review file, now written by the server on the
  desktop's behalf.
- **Auth is once per device.** The module's server requires the agenix UI
  password; the desktop must authenticate on first connect (retrievable with
  `make openchamber-password`).
- **Module surface grows for an externally-installed app.** `desktopClient`
  exists to configure something Nix does not install; the coupling is
  documented rather than implicit.

### Risks

- **`OPENCHAMBER_SERVER_URL` pins the startup target.** In-app host switching
  should still work because the env only seeds `resolveInitialUrl`, but this
  has to be confirmed on rollout (add/switch a host from the desktop UI).
- **Env-var channel.** A Dock/Finder launch starts with a minimal environment;
  the values arrive only through the login-shell probe. If the user's shell
  never sources Home Manager's session variables, the desktop silently falls
  back to its embedded server and the two-server hazards return.
- **Upstream drift.** These env names and the 57123 default are upstream
  implementation details, not a stable contract; a future release can rename
  them (`nix flake check` cannot catch this).

## Alternatives considered (and rejected)

| Alternative | Reason rejected |
|---|---|
| Package the release `.app` (DMG/zip) as a Nix derivation | Read-only store + the Electron self-updater overwrites the bundle; Gatekeeper/quarantine handling; ADR-0005's reason still holds |
| Build `packages/electron` from source in Nix | bun monorepo + electron-builder + native rebuild against the Electron ABI + network-fetched pinned OpenCode CLI (a FOD) + codesign/notarize (Apple credentials) — a large, separate project, and it still ships the self-updater |
| Two independent servers (desktop embedded, no client mode) | Works (ports differ) but two writers to one data dir and two relay/pairing registrations; kept only as the documented fallback |
| Relocate the desktop with `OPENCHAMBER_DATA_DIR` | Loses the shared sessions/projects that are the point of combining the surfaces, and a Dock launch cannot receive the env declaratively |
| `launchctl setenv` activation script for the two vars | Imperative, requires a re-login, and duplicates what Home Manager `sessionVariables` + the login-shell probe already provide |
| Point the desktop at `:4096` OpenCode directly and skip the module server | The desktop needs an OpenChamber *server* (not just OpenCode); skipping the module server re-creates the embedded-server split |

## References

- Upstream desktop runtime: `packages/electron/main.mjs`
  (`DEFAULT_DESKTOP_PORT`, `spawnLocalServer`, `resolveInitialUrl`,
  `shouldSkipLocalServer`), `packages/electron/early-startup.mjs`
  (`settingsFilePath`)
- Upstream server data root: `packages/web/server/index.js`
- Homebrew cask: <https://formulae.brew.sh/cask/openchamber>
- OpenChamber: <https://github.com/openchamber/openchamber>,
  <https://openchamber.dev>
- Module: `modules/openchamber.nix`; enablement: `home/agentic.nix`; cask:
  `darwin/openchamber.nix` (version-sync warning); server package:
  `packages/openchamber/`; cask tap input: `homebrew-cask` in `flake.nix`;
  shared OpenCode password: `secrets/opencode-server.age` +
  `programs.openchamber.opencodePasswordFile`
- Related: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0009
