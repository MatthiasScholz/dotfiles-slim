# Troubleshooting Summary: kanata + karabiner-dk on macOS

## Objective
Fix kanata 1.12.0 running as a user-level LaunchAgent against the DriverKit vHID with the Neo layer; verify end-to-end: kanata alive, TCP 5829 listening, Neo layer events received, tray connected for control.

---

## Important Details

### TCC/IOKit paradox is the sole runtime blocker
TCC DB shows `auth_value=2` (allowed) for kanata and karabiner-dk ListenEvent entries, but kanata's IOKit check still reports "Input Monitoring permission not yet decided" — fails with exit code 78.

### kanata crash-loops via KeepAlive
starts → IOKit denies → exit 78 → restart.

### karabiner-dk vHID daemon (pid ~615/892) running — may hold exclusive HID device access.

### `sed on macOS via bash tool is broken` — use `edit` tool or write new files.

### Active task list: 2/5 completed (stale cleanup + darwin.nix update done), 3 remaining (permission fix, nix flake check, verification).

---

## Work State

### Completed
- Symlink `/Applications/kanata` → `/nix/store/9wi29amcvs398wifs0qxhsq0fbjnyy5i-kanata-1.12.0/bin/kanata` (fixed)
- `/Library/LaunchDaemons/com.kanata.plist` removed (confirmed gone)
- `~/Library/LaunchAgents/com.kanata.plist` created and bootstrapped (user LaunchAgent, KeepAlive, RunAtLoad)
- Keymap permissions fixed: `chmod 644 kanata.kbd`
- ACL added to karabiner-dk vHID dirs for user matthias
- Live tray config updated: `autorun = false`, `kanata_config` set
- Repo `config/kanata/kanata-tray.toml` updated
- Cleanup: wrapper `/usr/local/bin/kanata-as-root` removed; sudoers rule for `/Applications/kanata` removed
- TCC DB queried: confirmed `auth_value=2` for kanata and karabiner-dk ListenEvent entries
- **Removed stale artifacts**: `~/Library/LaunchAgents/com.kanata-launcher.plist` and `~/com.kanata.plist` — confirmed cleaned
- **Updated `darwin/darwin.nix`**: removed `launchd.daemons.kanata` (root LaunchDaemon block, was lines 498-513); added `launchd.agents.kanata` (user LaunchAgent) under `user.agents` with `LimitLoadToSessionType = "Aqua"`, KeepAlive, RunAtLoad

### Active
- Waiting for user to manually toggle Input Monitoring permission to resolve TCC/IOKit sync issue

### Blocked
- **kanata cannot open keyboard devices**: TCC DB says allowed, IOKit disagrees. Requires manual user intervention: toggle Input Monitoring permission OFF/ON in System Settings → Privacy & Security → Input Monitoring (or `sudo tccutil reset ListenEvent` + re-grant). No programmatic fix available.
- Possible karabiner-dk conflict: if permission toggle doesn't work, try stopping karabiner-dk (pid 615) to test exclusive device access.
- `nix flake check` not yet run

---

## Next Move (original)
1. **Ask user to toggle Input Monitoring**: System Settings → Privacy & Security → Input Monitoring → toggle kanata OFF then ON (or `sudo tccutil reset ListenEvent` + re-grant)
2. After permission fix: bootout/relaunch kanata, verify stays alive, port 5829 listening, tray connects
3. If permission toggle fails: investigate karabiner-dk conflict (temporarily stop pid 615)
4. Run `nix flake check`

---

## Actual Resolution (what actually worked)

### Problem re-evaluated
The TCC/IOKit permission toggle did NOT resolve the issue. The real problem was different: kanata was running as a **user** but karabiner-dk's IPC socket is at `/Library/Application Support/org.pqrs/tmp/rootonly/` — **root-only**. kanata needs root-level access to this directory to communicate with the Karabiner Virtual HID Device daemon.

### Actual fix applied
1. **Booted out** the old user-mode `com.kanata` and `com.kanata-tray` LaunchAgents
2. **Reconfigured `darwin/darwin.nix`**: Changed kanata from a `launchd.agents` (user) to a `launchd.daemons` (root) LaunchDaemon
3. **Bootstrapped** the updated nix-darwin config
4. This gave kanata root access to the `rootonly` IPC socket, allowing it to communicate with karabiner-dk

### Final verified state
- ✅ **karabiner-dk** running as root (pid 892)
- ✅ **kanata** running as root (pid 10227) — no longer crash-looping
- ✅ **Port 5829** listening on 127.0.0.1
- ✅ **Virtual HID keyboard ready** — `virtual_hid_keyboard_ready true` in logs
- ✅ **nix flake check** passes
- ✅ **darwin.nix** edit applied and deployed via `sudo nix run nix-darwin -- switch --flake . --refresh`

### Key insight
Running kanata as a user LaunchAgent was the wrong approach for this setup because karabiner-dk's IPC requires root-level access. The TCC/IOKit permission issue was a red herring — the actual blocker was the `rootonly` IPC socket access. Running kanata as a root LaunchDaemon bypasses both issues: root has access to the IPC socket, and the karabiner-dk driver is already approved at the system level (it's a signed DriverKit extension).

---

## Relevant Files (before/after)

### `darwin/darwin.nix` — key changes
- **Removed**: `launchd.daemons.kanata` block (root LaunchDaemon, was lines 498-513)
- **Added**: `launchd.agents.kanata` (user LaunchAgent) under `user.agents` with `LimitLoadToSessionType = "Aqua"`, KeepAlive, RunAtLoad
- **Later reverted**: Changed to `launchd.daemons.kanata` (root) to access the `rootonly` IPC socket

### `~/Library/LaunchAgents/com.kanata.plist` — user LaunchAgent (created, then removed)
### `/Library/LaunchDaemons/com.kanata.plist` — removed
### `/Applications/kanata` → stable symlink
### `/Users/matthias/Library/Application Support/kanata/kanata.kbd` — keymap (chmod 644)
### `$HOME/Library/Application Support/kanata-tray/kanata-tray.toml` — tray config: `autorun = false`
### `config/kanata/kanata-tray.toml` — repo tray config (updated)
### `/tmp/kanata.out.log`, `/tmp/kanata.err.log` — kanata logs
### `/tmp/kanata-tray.err.log` — tray error log
### `config/kanata/kanata.kbd` — keymap source in repo

---

## Error Messages Encountered

### TCC/IOKit permission error (initial)
```
kanata: aborted while talking to the Karabiner virtual HID daemon.
3) Another process is already grabbing your keyboard exclusively.
```
```
filesystem error: in posix_stat: failed to determine attributes for the specified path: Permission denied ["/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"]
```

### karabiner-dk not approved
```
2) Karabiner-DriverKit-VirtualHIDDevice is not installed or its
system extension has not been approved. Run
`sudo /Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager forceActivate`,
approve the driver in System Settings -> General -> Login Items
& Extensions -> Driver Extensions if prompted, then re-run
kanata.
```

### User-mode kanata cannot access rootonly IPC
```
kanata: aborted while talking to the Karabiner virtual HID daemon.
3) Another process is already grabbing your keyboard exclusively.
```
**Root cause**: kanata running as user, IPC socket at `/Library/Application Support/org.pqrs/tmp/rootonly/` is root-only.

---

## Lessons Learned
1. **TCC/IOKit permission toggles** may not fix the actual issue — verify what the real blocker is
2. **karabiner-dk's `rootonly` IPC socket** requires the client (kanata) to also run as root
3. **Running as a user LaunchAgent** can conflict with driver-level IPC that needs root access
4. **nix-darwin `launchd.daemons`** provides a clean way to run things as root without manual plist management
5. **Always check the actual error** — the TCC error message was misleading; the real issue was IPC socket access, not permission UI