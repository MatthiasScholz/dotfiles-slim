# Context

Domain language for this repository. ADRs in [`docs/adr/`](docs/adr/) record the
decisions behind these terms; this file only fixes the names.

The flake has two surfaces:

- **home surface** — `home/` and `modules/`, evaluated by Home Manager (per user).
- **system surface** — `darwin/`, evaluated by nix-darwin (whole machine).

## Glossary

### managed service

A background process this repo declares in Nix and hands to launchd, rather than
installing it with a shell script or `foo startup enable`. Both launchd domains
count:

- **user agent** — Home Manager `launchd.agents.<name>`, started at login, e.g.
  OpenChamber and AgentsView. (`programs.opencode.web` is the same kind, produced
  by Home Manager itself.)
- **system daemon** — nix-darwin `launchd.daemons.<name>` (or `launchd.user.agents`),
  started at boot or login, e.g. `kanata`, `karabiner-dk`, `kanata-tray`.

A managed service is built with [`lib/launchd.nix`](lib/launchd.nix), which owns
the plist shape (RunAtLoad, KeepAlive, ProcessType, log paths, log-dir
activation) and the agenix start-order wrapper. Callers pass a command, a log
directory, and the secret files it must wait for.

### secret file

An agenix-decrypted file, by convention `~/.agenix/<name>`, read by a managed
service at start. Only the *path* enters the Nix store; the value never does
(ADR-0004). Two shapes:

- **raw value** — `cat` + `export VAR`, e.g. the OpenChamber UI password.
- **shell line** — `. file`, where the file holds `export NAME=…`, e.g. the
  shared `OPENCODE_SERVER_PASSWORD` read by both OpenCode and OpenChamber.

agenix decrypts from its own LaunchAgent at login, so a managed service waits
(bounded) for the file before starting.

### config sync-back

The review loop for a file a tool rewrites at runtime: copy the live file over
the version-controlled copy, strip or refuse secret-looking keys, print
`git diff`, and let a human accept or reject (ADR-0003). Entry points:
`scripts/sync-config-*.sh`, `make sync-config-*`.

### prebuilt artifact

A derivation that fetches a published release and pins per-platform hashes
instead of building from source — a GitHub release tarball (AgentsView) or an
npm platform tarball (OpenCode v2, `@openchamber/web`). See ADR-0005, ADR-0009.

### plugin pin

The version of a managed OpenCode plugin, recorded in
`modules/opencode-plugin-versions.nix` and refreshed by
`scripts/update-opencode-plugin-versions.sh` (run by `make update`).

### profile

An OpenCode configuration directory (`~/.config/opencode/profiles/<name>`)
selected per integration — `personal`, `omo`, `work`.
