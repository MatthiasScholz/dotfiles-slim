# Kanata + kanata-tray on macOS — troubleshooting

Working notes for the kanata / kanata-tray / karabiner-dk stack. For the
design rationale see [ADR-0002](adr/0002-kanata-tray-lifecycle-twin.md) and
[ADR-0006](adr/0006-kanata-tcc-stable-signing.md); this file is the operator
runbook.

> Historical session notes (user-LaunchAgent experiments, the
> `/Applications/kanata` symlink, the Homebrew wrapper hack) are obsolete.
> The activation script now removes `/Applications/kanata` and writes to the
> stable paths below.

## Architecture in one paragraph

kanata runs as a **root LaunchDaemon** (`com.kanata`, `/usr/local/bin/kanata`)
because the Karabiner-DriverKit vHID socket lives in a root-only directory.
kanata-tray runs as a **user LaunchAgent** (`com.kanata-tray`), but it cannot
spawn kanata itself, so it runs the **lifecycle shim**
(`/usr/local/bin/kanata-tray-shim`) which starts/stops the daemon through the
privileged helper (`/usr/local/libexec/kanata-manage`, narrow NOPASSWD
sudoers rule) and mirrors daemon liveness by polling TCP 5829. The activation
script in `darwin/darwin.nix` reconciles all of it on every switch.

**The binary is copied to a stable path and re-signed with a stable
identity.** macOS TCC resolves symlinks and pins an ad-hoc binary's grant to
its cdhash, so the activation copies `${pkgs.kanata-with-cmd}` to
`/usr/local/bin/kanata` and re-signs it with the machine-local `kanata-tcc`
self-signed identity. TCC then stores the content-independent requirement
`identifier "com.kanata.kanata" and certificate leaf = H"…"`, which survives
`nix flake update` + `make setup`. See ADR-0006.

Paths:

| What | Where |
|---|---|
| kanata binary (stable copy, re-copied + re-signed each switch) | `/usr/local/bin/kanata` |
| content stamp used to skip no-op re-copies | `/usr/local/libexec/kanata.src-sha256` |
| keymap (copied from `config/kanata/basbousa.kbd`) | `~/Library/Application Support/kanata/kanata.kbd` |
| tray config (copied from `config/kanata/kanata-tray.toml`) | `~/Library/Application Support/kanata-tray/kanata-tray.toml` |
| shim / helper | `/usr/local/bin/kanata-tray-shim`, `/usr/local/libexec/kanata-manage` |
| sudoers rule | `/private/etc/sudoers.d/kanata-manage` |
| logs | `/tmp/kanata.{out,err}.log`, `/tmp/kanata-tray.{out,err}.log` |

## Quick health check

```bash
# Daemon loaded and running?
sudo launchctl print system/com.kanata | grep -E 'state|pid'

# Is kanata listening on the TCP port the tray talks to?
nc -z 127.0.0.1 5829 && echo UP || echo DOWN

# Tray + shim alive?
pgrep -fl 'kanata-tray$|kanata-tray-shim'

# Recent errors
tail -n 40 /tmp/kanata.err.log
tail -n 40 /tmp/kanata-tray.err.log
```

Healthy state: daemon `state = running`, port 5829 UP, one `kanata-tray` and
one `kanata-tray-shim` process, and the tray log shows
`Connected to kanata via TCP`.

## Symptom: keys aren't remapped / tray icon shows "crash"

Check the kanata error log first. If it says:

```
failed to open keyboard device(s): macOS Input Monitoring permission is
denied for kanata. Enable kanata in System Settings -> Privacy & Security ->
Input Monitoring, then re-run kanata.
```

then TCC's stored requirement no longer matches `/usr/local/bin/kanata`.
Diagnose:

```bash
codesign -dvvv /usr/local/bin/kanata                 # current identity
codesign -d -r- /usr/local/bin/kanata                # designated requirement
security find-identity -v -p codesigning /Library/Keychains/System.keychain
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "SELECT service, auth_value, hex(csreq) FROM access WHERE client='/usr/local/bin/kanata';"
```

- If the requirement is `identifier "com.kanata.kanata" and certificate leaf =
  H"…"` and the identity exists, TCC should match; a mismatch means the grant
  is stale or was never re-added (see below).
- If the requirement is `cdhash H"…"`, the binary is not signed with the
  stable identity — something bypassed the activation. Re-run `make setup`.

`com.kanata` has `KeepAlive`, so a denied start crash-loops and the tray's
shim `post-stop` hook then stops the daemon (tray shows "crash"). Because the
grant cannot be migrated programmatically (SIP keeps `TCC.db` read-only;
`tccutil` cannot target a path client) and a root daemon can never be shown a
prompt, the fix is a manual remove/re-add — the **one-time** grant.

**Both permissions are mandatory.** kanata's `KbdIn::new` pre-flights Input
Monitoring and then Accessibility and hard-fails if either is missing:
without Accessibility, opening keyboards through the Karabiner DriverKit stack
returns `IOHIDDeviceOpen error: (iokit/common) not permitted`
(`kIOReturnNotPermitted`, upstream issue #1211). Input Monitoring is checked
*first*, so when both entries are stale you only ever see the Input Monitoring
error — do not conclude Accessibility is optional.

1. **System Settings → Privacy & Security → Input Monitoring**: remove
   `/usr/local/bin/kanata` (`−`), then `+` → ⌘⇧G → `/usr/local/bin` → `kanata`.
2. **System Settings → Privacy & Security → Accessibility**: same.
3. Start/reload the daemon:

   ```bash
   sudo /usr/local/libexec/kanata-manage start
   ```

   Use the helper, not `launchctl kickstart`: after a crash-loop the shim's
   `post-stop` hook `bootout`s and `disable`s `com.kanata`, so
   `launchctl kickstart system/com.kanata` fails with
   `Could not find service "com.kanata" in domain for system`. The helper
   re-enables, bootstraps and kickstarts it (and is NOPASSWD).

This is needed when the identity is first adopted, and again only if the
System-keychain identity is deleted and regenerated (a new certificate is a
new requirement).

## Updating kanata

Nothing special: update the flake and switch.

```bash
make update && make setup
# verify the daemon is running the new copy:
sudo launchctl print system/com.kanata | grep state
```

The activation re-copies and re-signs when the source binary changes, and the
tray restart cycle reloads the daemon. The TCC grant is unaffected because the
requirement is identity-based.

## The `kanata-tcc` code-signing identity

Created once by the activation if missing:

- self-signed, `extendedKeyUsage = codeSigning`;
- imported into the root-only **System keychain**, private key restricted to
  `/usr/bin/codesign` (no `-A`);
- trust added for the **`codeSigning` policy only** (does not affect TLS);
- private key never enters the repo or the nix store.

```bash
security find-identity -v -p codesigning /Library/Keychains/System.keychain
codesign -d -r- /usr/local/bin/kanata    # should show "certificate leaf"
```

### Recreating the identity (rare)

Only needed if the identity is lost or deliberately rotated. A new
certificate means a **new TCC requirement**, so a re-grant is required
afterwards (the daemon will crash-loop until then).

1. Note the current identity hash (the 40-hex value):

   ```bash
   security find-identity -v -p codesigning /Library/Keychains/System.keychain
   # 1) D5B73E21AE4839643DDF11460B27BFDCFCF08E5F "kanata-tcc"
   ```

2. Delete the certificate + private key:

   ```bash
   sudo security delete-identity -Z D5B73E21AE4839643DDF11460B27BFDCFCF08E5F \
     /Library/Keychains/System.keychain
   ```

   (`-Z` accepts the SHA-1 or SHA-256 hash. `add-trusted-cert -d` writes to the
   **admin** trust store, which `delete-identity -t` does *not* touch; a
   dangling cert-less trust record can remain and is harmless — there is no
   matching certificate.)

3. Regenerate and re-sign with any switch:

   ```bash
   make setup
   # the activation sees no kanata-tcc, creates a new one, re-signs the binary
   ```

4. Verify the new identity and requirement:

   ```bash
   security find-identity -v -p codesigning /Library/Keychains/System.keychain
   codesign -d -r- /usr/local/bin/kanata    # certificate leaf = H"<new hash>"
   ```

5. Re-grant Input Monitoring + Accessibility (see the grant steps above;
   remove then re-add), then start the daemon:

   ```bash
   sudo /usr/local/libexec/kanata-manage start
   ```

## Symptom: `/tmp/kanata.out.log` is enormous

A TCC crash-loop scribbles into this file on every restart (it has been seen
at ~100 MB). Truncate it once the loop is stopped:

```bash
sudo truncate -s 0 /tmp/kanata.out.log
sudo truncate -s 0 /tmp/kanata.err.log
```

## Pause/resume

kanata-tray's `post-stop` hook runs
`sudo -n /usr/local/libexec/kanata-manage stop`, which `launchctl disable`s and
`bootout`s `com.kanata` (the pause persists across reboots). Start again from
the tray preset, or manually:

```bash
sudo /usr/local/libexec/kanata-manage start
```

If `sudo -n` fails, the NOPASSWD rule is missing/corrupt. It is rewritten on
every activation and validated with `visudo -cf`; re-run `make setup` to
restore it.

## karabiner-dk notes

- The nix `karabiner-dk` daemon (`com.karabiner.VirtualHIDDevice-Daemon`) is
  what nix kanata talks to (`SOCK_DGRAM` / `pqrs::local_datagram`). The
  Homebrew Karabiner-Elements daemon uses `SOCK_STREAM` and is **incompatible**
  with nix kanata.
- The vHID IPC socket is root-only
  (`/Library/Application Support/org.pqrs/tmp/rootonly/`), which is why
  kanata must be a root daemon.
- `karabiner-dk` logs: `/tmp/karabiner-dk.{out,err}.log`.
