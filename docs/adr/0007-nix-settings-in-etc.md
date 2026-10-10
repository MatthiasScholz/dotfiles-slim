# ADR-0007: Nix configuration is system-scoped in `/etc/nix`, not per-user

- **Status**: Accepted
- **Date**: 2026-10-08
- **Deciders**: Matthias (config owner), coding agent
- **Related**: ADR-0004 (agenix / secret placement — owner of the user-level
  GitHub access token), `Makefile` `switch`/`setup` (`SUDO ?= sudo -H`),
  ADR-0001 (reconciling imperative tooling into declarative Nix)

## Context

`make switch` / `make setup` run nix-darwin as root:

```make
SUDO ?= sudo -H
switch:
	$(SUDO) nix run nix-darwin -- switch --show-trace --flake ~/projects/config/dotfiles-slim
```

Plain `sudo` keeps the invoking user's `HOME` (`/Users/matthias`) while the
effective uid becomes `root`. Nix noticed the mismatch and warned:

```text
warning: $HOME ('/Users/matthias') is not owned by you, falling back to the
one defined in the 'passwd' file ('/var/root')
```

`sudo -H` (`--set-home`) sets `HOME=/var/root` up front, which removes the
warning — but it also makes an existing, desirable property explicit: **the
root `nix` invocation, and the `nix-daemon` it talks to, read the system Nix
configuration under `/etc/nix`, never any user's `~/.config/nix/nix.conf`.**

### How Nix composes configuration

Per the Nix manual, settings are read in order and later entries override
earlier ones:

1. the system-wide file, `${sysconfdir}/nix/nix.conf` (`/etc/nix/nix.conf`);
2. the per-user file, `$XDG_CONFIG_HOME/nix/nix.conf`
   (`~/.config/nix/nix.conf`), or `NIX_USER_CONF_FILES`, or `XDG_CONFIG_DIRS`;
3. `NIX_CONFIG`, then command-line flags.

So a user's `~/.config/nix/nix.conf` overrides the system file *for that
user*, but is invisible to `root` (`HOME=/var/root`) and to the daemon, which
loads the system file only. Settings that the daemon, remote builders, or a
root switch must honour therefore **have** to live in `/etc/nix`.

### What this repo actually has (verified 2026-10-08)

| Setting | File | Read by a root `nix run … switch`? |
|---|---|---|
| `eval-cores`, `extra-substituters`, `extra-trusted-public-keys` (devenv/Cachix) | `/etc/nix/nix.custom.conf` | ✅ |
| Determinate defaults (`max-jobs`, FlakeHub substituters, `netrc-file`, keychain cert) | `/etc/nix/nix.conf` (Determinate-owned) | ✅ |
| Remote builders | `/etc/nix/machines` | ✅ |
| Remote-builder SSH hosts | `/etc/ssh/ssh_config.d/remote-builders.conf` | ✅ |
| GitHub `access-tokens = github.com=…` | `~/.config/nix/nix.conf` | ❌ (and that is fine) |

Two facts shape the layout:

- **Determinate owns `/etc/nix/nix.conf`.** Its header is *"do not modify!
  this file will be replaced!"*, and it pulls in a sibling via
  `!include nix.custom.conf`. `nix.custom.conf` is the supported extension
  seam. Determinate's own `nix-darwin` module and this repo both target it
  (`environment.etc."nix/nix.custom.conf".text`, a `types.lines` option, so
  the two definitions concatenate).
- **`nix.enable = false`.** The Nix installation is managed by the
  Determinate installer, not nix-darwin (`darwin/nix.nix`). nix-darwin's
  `nix.settings`/`nix.gc`/`nix.optimise` modules are built around
  `nix.enable = true`, so they are not the mechanism here; the repo writes
  `nix.custom.conf` directly through `environment.etc`.

The same reasoning already applies to the remote builders in
`darwin/remote-builders.nix`: *"root does not read the user's `~/.ssh/config`"*, so the
SSH aliases are installed system-wide. ADR-0007 generalises that principle to
Nix settings.

## Decision

**System-scoped Nix settings are owned by nix-darwin under `/etc/nix`; the
per-user `~/.config/nix/nix.conf` is reserved for user-only, non-build
settings.**

1. `/etc/nix/nix.conf` is treated as read-only (Determinate-owned). All
   repo-managed settings go through `environment.etc."nix/nix.custom.conf"`
   in `darwin/nix.nix`, which Determinate includes.
2. Anything a `make switch` / `make setup` (root), the daemon, or a remote
   builder must see — substituters, trusted keys, trusted users, `eval-cores`,
   builder aliases — is declared in `nix.custom.conf` (or `/etc/nix/machines`,
   `/etc/ssh/ssh_config.d/…`) and reviewed in git.
3. The user config stays in `~/.config/nix/nix.conf` and holds only settings
   that are meaningful per interactive user. Today that is exactly one entry:
   the GitHub `access-tokens` used by user-run commands such as
   `nix flake update`. Home Manager does not manage this file; it is seeded
   manually and is not in version control.
4. `sudo -H` on the switch targets is the intended invocation, not a
   workaround to suppress a log line: it guarantees root reads root's Nix
   configuration (`/etc/nix/…`) and not the operator's.
5. If a root-executed command ever needs the GitHub token, it is added to the
   system side (Determinate already sets `netrc-file =
   /nix/var/determinate/netrc`) — never by lifting the user file into root's
   scope.

## Consequences

### Positive

- **One owner per scope.** A setting's file tells you who it applies to; no
  "works for me, fails under `sudo`" class of bug.
- **Reproducible root builds.** The daemon and the switch do not inherit an
  operator's local overrides, so a build is a function of the flake plus the
  system config that is itself in git.
- **Declarative and reviewable.** Substituters, trusted keys and builders are
  diffable Nix, not hand-edited files. Manual `/etc/nix/nix.conf` edits are
  impossible to keep (Determinate replaces the file).
- **Correct defaults for tooling.** Root-run `nix` falls back cleanly to
  `/var/root` with no warning, and the user env is irrelevant to activation.

### Negative

- **Scope is a thing to know.** Editing `~/.config/nix/nix.conf` and
  expecting a switch to pick it up does nothing; the fix is to move the
  setting into `nix.custom.conf`.
- **Two places to look.** "Why is my substituter not used?" now has two
  candidate files (`nix.custom.conf` vs the user file). The table above is the
  map.
- **Root fetches lack the user token.** A private flake fetched by root needs
  `netrc-file`/a system credential; the current `make switch` uses a local
  path flake and does not.

### Risks

- **Silent divergence.** Adding `trusted-users`, `substituters` or
  `access-tokens` to the user file while believing they are global is the
  failure mode this ADR exists to prevent; those belong in
  `nix.custom.conf`.
- **Stale documentation.** `README.md` still tells the reader to add binary
  caches by editing `/private/etc/nix/nix.custom.conf` by hand. That file is a
  symlink into `/etc/static`, so hand edits are transient; the README must
  point at `darwin/nix.nix` instead. (Follow-up, not blocking.)
- **Determinate changes the seam.** If a future Determinate release stops
  including `nix.custom.conf`, settings silently stop applying; caught by a
  periodic `nix config show` / cache-hit sanity check.

## Alternatives considered (and rejected)

| Alternative | Reason rejected |
|---|---|
| Plain `sudo nix …` (no `-H`), tolerate the warning | The effective uid is root but `HOME` is the operator's: Nix warns, and any evaluation that consults `$HOME`-relative state uses the wrong home. `-H` is the correct invocation, so adopt it rather than paper over the log line |
| Keep all settings in `~/.config/nix/nix.conf` | The daemon/root never reads it. System substituters, trusted keys and builders would not apply to root builds, which is where nix-darwin activation runs |
| Use nix-darwin `nix.settings` | Requires `nix.enable = true` and nix-darwin owning the install; conflicts with the Determinate-managed `nix.conf` (ADR rationale in `darwin/nix.nix`) |
| Edit `/etc/nix/nix.conf` directly | Header says *"do not modify! this file will be replaced!"*; changes are lost on the next Determinate upgrade |
| Rely on `NIX_CONFIG` / `NIX_USER_CONF_FILES` in the Makefile | Per-invocation and invisible to the daemon; hides system policy in a shell wrapper instead of in reviewed Nix |

## References

- Nix manual, *nix.conf* — configuration-file order and `extra-` prefixing:
  <https://nix.dev/manual/nix/latest/command-ref/conf-file>
- Determinate Systems installer / Determinate Nix:
  <https://github.com/DeterminateSystems/nix-installer>
- `darwin/nix.nix` — `environment.etc."nix/nix.custom.conf"`;
  `darwin/remote-builders.nix` — `nix/machines`, `ssh/ssh_config.d/remote-builders.conf`
- `Makefile` — `SUDO ?= sudo -H`, `switch`, `setup`
- `README.md` — *Binary Caches*, *Github Access* (token in
  `~/.config/nix/nix.conf`)
- ADR-0004 — secret placement; the `access-tokens` entry is the sole
  user-level Nix setting this ADR leaves in place
