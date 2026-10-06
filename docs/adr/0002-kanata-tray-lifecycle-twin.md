# ADR-0002: Kanata Root LaunchDaemon with Tray Lifecycle Twin

- **Status**: Accepted
- **Date**: 2026-09-19
- **Deciders**: Matthias (config owner), coding agent

## Context

Kanata (via [Karabiner-DriverKit-VirtualHIDDevice](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice))
is the keyboard remapping layer of this machine (Neo2 via `basbousa.kbd`).
The previous setup had repeatedly broken after `nix flake update` +
`darwin-rebuild switch`, and its last mitigation ("hacking mode") embedded
state outside the flake: a wrapper script smuggled into the Homebrew
`kanata-tray` Cellar (`bin/kanata-tray.real` plus a hand-written wrapper) and a
sudoers rule pinned to a versioned Cellar path (`/opt/homebrew/Cellar/kanata-tray/0.8.0/…`).
Requirement: Kanata must work — including the tray icon for
pause/resume/status — after **every** nix update and switch, with no version-,
path- or session-dependent one-off state.

Three platform facts drove the design:

1. **TCC pins permissions to the real, resolved executable path.**
   `System Settings → Privacy & Security → Input Monitoring` grants are
   attributed to the *resolved* executable path, not to a symlink. Evidence:
   `tccd` logs `notifyUserOfDeniedAccessBy: for /nix/store/<new-hash>/bin/kanata`
   while the approved entry pointed at `/Applications/kanata`. The nix store
   hash changes on every rebuild that touches the package, so a store path —
   or a symlink to one — invalidates the grant every update.
2. **Root daemons cannot receive a TCC prompt.** `tccd` log:
   `notifyUserOfDeniedAccessBy … fails when requestor has UID 0`. A crash
   loop (`launchctl` `runs = 9918`, exit code 1) is invisible; the user cannot
   approve a daemon that never appears in the GUI.
3. **kanata itself requires root.** The latest
   [`docs/setup-macos.md`](https://github.com/jtroo/kanata/blob/main/docs/setup-macos.md)
   prescribes: kanata must run as root because the Karabiner virtual HID
   daemon exposes its IPC under
   `/Library/Application Support/org.pqrs/tmp/rootonly/` (mode `0700 root`),
   and it must read physical keyboards (TCC Input Monitoring) while writing
   through the DriverKit virtual device.

A fourth fact defined how the *tray* must be integrated: **kanata-tray
(rszyma/kanata-tray v0.8.0) is hardcoded to spawn and own the kanata process**
(`runner.Run → exec.CommandContext → cmd.Wait`). It has no "monitor an
external daemon" mode; its icon state is derived purely from the child
process lifecycle. Conversely, a kanata spawned by the tray (user context)
cannot open the root-only vHID socket — the core conflict.

## Decision

Split the process into three cooperating parts, all reconciled by
`darwin/darwin.nix` on every activation:

1. **Root LaunchDaemon `com.kanata`** (`launchd.daemons.kanata`) — the real
   kanata remapping process, using a stable binary copy and delegated to the
   privileged helper for lifecycle control (see below). TCC permissions
   (Input Monitoring + Accessibility) are granted **once** to
   `/usr/local/bin/kanata`.
2. **Stable real-file copy at `/usr/local/bin/kanata`, re-signed with a stable
   identity** (activation script; absolute rule: *copy, never symlink* — TCC
   resolves symlinks). TCC pins an ad-hoc binary's grant to its cdhash, which
   changes on every rebuild, so the copy is signed with the machine-local
   `kanata-tcc` identity; TCC then stores a content-independent requirement and
   the copy can be refreshed every switch. See **ADR-0006** for the full
   decision, the one-time grant, and the rejected alternatives.
3. **Tray lifecycle twin** — because kanata-tray must own a child process and
   that child must run as the user, the tray runs a **shim**
   (`/usr/local/bin/kanata-tray-shim`) instead of kanata itself:
   - the shim starts the root daemon through a root-owned helper
     (`/usr/local/libexec/kanata-manage`), which is the only command allowed
     via a narrow NOPASSWD sudoers rule (`%admin`, path version-independent,
     validated by `visudo -cf` at activation);
   - the shim then mirrors the daemon's liveness by polling the kanata TCP
     port (5829) with startup-wait (15 s) and a ~5 s outage tolerance;
     it exits when the port is down → the tray icon states — active / idle /
     crash — always reflect the **real** daemon state;
   - when the user pauses the preset, the tray SIGKILLs the shim, and the
     tray's `post-stop` hook runs `sudo -n /usr/local/libexec/kanata-manage stop`,
     which `boots out` the LaunchDaemon (plus `launchctl disable` semantics to
     persist the pause across reboots until re-enabled).
4. **Homebrew `kanata-tray` is kept pristine** (the embedded wrapper hack was
   removed) and runs as a declarative nix-darwin user LaunchAgent
   (`launchd.user.agents.kanata-tray`, `KeepAlive`, `RunAtLoad`) so it starts
   at every login and survives switches; the activation script also
   `launchctl kickstart`s it so it picks up updated TOML.

Everything lives under stable, version-independent paths
(`/usr/local/bin`, `/usr/local/libexec`, `/private/etc/sudoers.d/kanata-manage`)
written by the flake's activation script — no store hashes, no Cellar
versions, no manual steps besides the one-time TCC grant.

## Architecture

```mermaid
flowchart TB
    subgraph system["Root context (system launchd, no TCC prompts possible)"]
        DK["karabiner-dk LaunchDaemon<br/>(Karabiner-VirtualHIDDevice-Daemon, nix pkgs.karabiner-dk 6.6.0)<br/>provides SOCK_DGRAM vHID socket"]
        VHID[(DriverKit dext<br/>org.pqrs.Karabiner-<br/>VirtualHIDDevice<br/>virtual keyboard)]
        KANATA["kanata daemon (root LaunchDaemon com.kanata, KeepAlive)<br/>/usr/local/bin/kanata (stable real-file copy)<br/>read physical keyboards | write via vHID | serve TCP 5829"]
        SOCK[(root-only socket<br/>/Library/Application Support/org.pqrs/tmp/rootonly/)]
        KBD[Physical keyboards]
    end

    subgraph user["User context (GUI session)"]
        SHIM["kanata-tray-shim<br/>/usr/local/bin/kanata-tray-shim<br/>sudo -n manage start; polls TCP 5829"]
        TRAY["kanata-tray LaunchAgent (com.kanata-tray)<br/>/opt/homebrew/bin/kanata-tray<br/>menubar status icon"]
        HELPER["privileged helper<br/>/usr/local/libexec/kanata-manage start or stop<br/>bootstrap, kickstart, bootout, disable"]
        SUDO{{"sudoers rule<br/>%admin NOPASSWD:<br/>kanata-manage only"}}
        TCC{{"TCC (granted once, by hand)<br/>Input Monitoring + Accessibility<br/>for /usr/local/bin/kanata"}}
    end

    TCC -. grants .-> KANATA
    KBD --> KANATA
    DK --- VHID
    DK -- IPC --> KANATA
    KANATA -- output --> VHID
    KANATA -- "TCP 5829 events" --> TRAY

    TRAY -- "spawns and owns (preset)" --> SHIM
    SHIM -- "sudo -n" --> SUDO
    SUDO -. authorizes .-> HELPER
    SHIM -- "polls port mirroring liveness" --> KANATA
    HELPER -- start --> KANATA
    TRAY -- "post-stop hook" --> HELPER
    HELPER -- stop --> KANATA

    ACT["nix-darwin activation script<br/>(darwin/darwin.nix)<br/>writes binary copy, shim, helper, sudoers, toml, config; kickstarts tray"]
    ACT -.reconciles on every switch.-> system
    ACT -.-> SHIM
    ACT -.-> HELPER
```

## Consequences

- **Update-proof via stable signing (ADR-0006)**: the TCC-relevant path and
  the shim/helper paths are constants, and `/usr/local/bin/kanata` is
  re-copied and re-signed with the stable `kanata-tcc` identity on every
  switch. TCC stores a content-independent requirement, so the Input
  Monitoring / Accessibility grants survive `nix flake update` + `make setup`.
  The original "stable copy alone" claim was wrong: an ad-hoc binary's grant is
  pinned to its cdhash, which changes whenever nixpkgs rebuilds kanata (even at
  the same version) — the recurring breakage.
- **One manual step: the initial grant.** Moving onto the signed binary needs
  one remove/re-add of `/usr/local/bin/kanata` in Input Monitoring +
  Accessibility. Root daemons cannot be shown a TCC prompt, and the grant
  cannot be migrated programmatically (SIP keeps `TCC.db` read-only; `tccutil`
  cannot target a path client). Afterwards it is decoupled from switches.
- **Icon accuracy**: the tray's state machine watches the shim, which watches
  the daemon's TCP port; short TCP outages (≤ ~5 s, e.g. a live reload) are
  tolerated so the icon does not flicker to "crashed".
- **Pause persists across reboots** (helper `stop` keeps the launchd
  service disabled) until the tray preset is started again.
- **Delegation boundary**: privileged surface is a single root-owned script
  restricted to `start|stop` of exactly `com.kanata`; no generic NOPASSWD.
- **Trade-off**: restarted-stale-binary — after a switch that changes the
  kanata binary, the daemon keeps the previously loaded copy until the next
  shim start (`kickstart`) or reboot. Accepted, because the plist itself
  stays content-stable (no store hashes embedded), which also prevents
  nix-darwin from noisily restarting the remapping daemon mid-session.
- **If zero-touch signing ever needs a system-managed root of trust** (many
  machines): a real Apple Developer ID can replace the self-signed identity.
  Seeding `TCC.db` was proven impossible: SIP keeps it read-only even with Full
  Disk Access.

## Amendment — 2026-10-05: stable code signing adopted (see ADR-0006)

The original design assumed a stable-path *copy* alone would keep the TCC
grant. After a `nix flake update` + switch the tray went to "crash" again:
the copied binary's ad-hoc cdhash had changed (same kanata 1.12.0, newer
nixpkgs), while TCC still pinned the old `cdhash H"290369c7…"`.

An interim "install only when missing" freeze avoided the breakage but left the
binary silently stale. **ADR-0006** replaced it with a stable self-signed
code-signing identity (`kanata-tcc`): the copy is refreshed and re-signed on
every switch, and TCC's requirement becomes content-independent. The only cost
is a one-time manual re-grant, which could not be automated because `TCC.db` is
SIP-read-only and `tccutil` cannot target a path-based client.

## Alternatives considered (and rejected)

| Alternative                                                                              | Reason rejected                                                                                                                                                                |
|------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Run kanata as a user LaunchAgent / let the tray spawn kanata directly (upstream default) | Karabiner vHID socket is root-only (`tmp/rootonly`, mode 0700); user-context kanata can neither open it nor use the dext path. Tried and documented in past commits; dead end. |
| Keep the `/Applications/kanata` symlink for TCC                                          | TCC resolves symlinks — the logged attribution was always the store path, so the grant silently died on every update.                                                          |
| Directly seed `/Library/Application Support/com.apple.TCC/TCC.db`                        | Requires FDA/SIP-exempt writes to a TCC-managed database; not portable across macOS updates; defeats the "no hacking" requirement.                                             |
| Replace kanata-tray with a custom menubar app (Hammerspoon agent etc.)                   | Most maintenance burden; kanata-tray already provides pause/resume + layer icons; the shim pattern reuses it unchanged.                                                        |
| Keep the old Homebrew wrapper + sudoers-via-Cellar hack                                  | Broke on every `brew upgrade` (versioned path), state outside the flake, irreproducible; the reason for this ADR.                                                              |

## References

- kanata macOS setup guide: <https://github.com/jtroo/kanata/blob/main/docs/setup-macos.md>
- kanata-tray (runner owns the child process): <https://github.com/rszyma/kanata-tray>
- Karabiner-DriverKit-VirtualHIDDevice (root-only IPC socket): <https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice>
- Implementation: `darwin/darwin.nix` (activation script, `launchd.daemons.kanata`,
  `launchd.user.agents.kanata-tray`), `config/kanata/kanata-tray.toml`
- ADR-0006 — stable code-signed kanata copy (supersedes this ADR's binary
  installation detail)
- Operator runbook (health checks, TCC re-grant, file sizes):
  [`docs/troubleshooting.md`](../troubleshooting.md)
- Related: ADR-0001 — same theme of reconciling imperative tooling
  (installer/wrapper hacks) into a declarative Nix module.
