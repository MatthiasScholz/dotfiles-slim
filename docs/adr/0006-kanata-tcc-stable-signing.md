# ADR-0006: Stable code-signed kanata copy so TCC survives nix rebuilds

- **Status**: Accepted
- **Date**: 2026-10-05
- **Deciders**: Matthias (config owner), coding agent
- **Related**: ADR-0002 (kanata root daemon + tray lifecycle twin),
  ADR-0001 (reconciling imperative tooling into declarative Nix)

## Context

kanata must run as a **root LaunchDaemon** (the Karabiner-DriverKit vHID
socket is root-only) but still receives a macOS **TCC Input Monitoring**
grant. ADR-0002 addressed the resulting breakage by copying the binary to a
stable path, `/usr/local/bin/kanata`, on the theory that a stable path keeps
the grant. That theory was incomplete.

Three TCC facts, established empirically:

1. For a non-bundled executable, TCC's **client key is the resolved real
   path**, and for an ad-hoc signed binary its **code requirement is the
   cdhash**. Both change whenever Nix rebuilds the package — even at the same
   kanata version, a nixpkgs bump produces a new store hash and new bytes.
2. Root processes can never be shown a TCC prompt, so a grant cannot be
   created or refreshed interactively for the daemon.
3. The grant **cannot be migrated programmatically**: `TCC.db` is read-only
   under SIP even with Full Disk Access (`attempt to write a readonly
   database`), and `tccutil reset` only accepts bundle identifiers, not the
   path-based client (`No such bundle identifier`).

The concrete failure: after a `nix flake update` + switch, `/usr/local/bin/kanata`
held `kanata-1.12.0` build `7lbq…` (cdhash `59e3ed…`), while TCC still pinned
`cdhash H"290369c7…"` from the previous build `7v7jy…`. tccd logged
`Failed to match existing code requirement … kTCCServiceListenEvent`, kanata
exited 78, `KeepAlive` crash-looped it, and the tray's shim `post-stop` hook
stopped the daemon. Re-granting required a manual remove/re-add in System
Settings.

A copy is unavoidable for a TCC-stable CLI daemon: TCC resolves symlinks, so a
store symlink is attributed to the store path, and running the store path
directly makes the grant die on the next hash change. macOS convention for
privileged tools is likewise a stable system path. The open question is how
the copy is kept both **fresh** and **matched to a stable TCC requirement**.

## Decision

**Option A — keep a stable-path copy, and give it a stable, content-independent
code signature.**

The activation script in `darwin/darwin.nix`:

1. **Creates a machine-local self-signed code-signing identity once**
   (`kanata-tcc`) in the root-only System keychain, guarded by
   `security find-identity`:
   - self-signed, `extendedKeyUsage = codeSigning`;
   - private key imported with access restricted to `/usr/bin/codesign`;
   - trust added for the **`codeSigning` policy only** (no TLS/other).
   The key never enters the repo or the Nix store.
2. **Copies `${pkgs.kanata-with-cmd}/bin/kanata` to `/usr/local/bin/kanata`**
   when the source content changed (tracked with a `/usr/local/libexec`
   sha256 stamp so unrelated switches are no-ops).
3. **Re-signs the copy** with `kanata-tcc` and identifier
   `com.kanata.kanata`, so TCC stores the content-independent requirement
   `identifier "com.kanata.kanata" and certificate leaf = H"…"`.
4. **Verifies** the resulting requirement contains `certificate leaf`, failing
   loudly otherwise.

Because the requirement no longer contains the binary hash, a future
`nix flake update` + `make setup` refreshes the copy and the existing grant
keeps matching. The only manual step is the **initial** grant (and again only
if the keychain identity is deliberately recreated), by macOS design.

Refreshing the *running* daemon is already handled by the existing tray
cycle: the activation `kickstart -k`s the tray, whose `post-stop` hook stops
the daemon and whose preset restart starts it again — so the new binary is
loaded on the same switch.

## Consequences

- **Update-proof, not frozen**: store hash changes flow through on every
  switch; the grant survives because it is identity-based. This fixes both the
  recurring post-update breakage (ADR-0002) and the staleness of the interim
  "install only when missing" freeze.
- **One manual grant**: Input Monitoring + Accessibility must be removed and
  re-added for `/usr/local/bin/kanata` **once** after moving to the signed
  binary. It is decoupled from the normal switch cycle. **Both are mandatory**:
  kanata's `KbdIn::new` pre-flights Input Monitoring and then Accessibility
  and hard-fails without either (Input Monitoring gates `IOHIDCheckAccess`;
  Accessibility is required for the Karabiner DriverKit `IOHIDDeviceOpen`,
  upstream issue #1211). Input Monitoring is checked first, so a stale pair
  only surfaces the Input Monitoring error.
- **Imperative activation step**: the binary is copied/signed by
  `system.activationScripts.extraActivation.text`, not by a store path. This
  is the standard nix-darwin mechanism for OS-expected locations; signing
  cannot happen at build time because the private key lives in the System
  keychain.
- **Trust surface**: a trust entry for the `codeSigning` policy only, plus a
  root-keychain key restricted to `codesign`. `TCC.db` still keys the grant to
  the path, so the identity cannot be used to obtain grants for other clients.
- **Residual risk**: if the System-keychain identity is lost/recreated, a new
  certificate means a new requirement and one re-grant. The identity guard
  prevents accidental recreation. Rotation workflow: `docs/troubleshooting.md`
  → *Recreating the identity*.

## Alternatives considered

| Alternative | Reason rejected |
|---|---|
| **B. Pin kanata and run from the store (no copy)** | Works and is more declarative, but needs a dedicated pinned `nixpkgs`/kanata input (a second nixpkgs in the closure), still needs one grant for the store path client, and turns every kanata update into a pin bump. It trades one imperative copy for a heavier, hand-pinned dependency for no functional gain. Kept as the fallback if the copy is ever unacceptable. |
| **Freeze the copy (install only when absent)** | Zero interaction, but the installed binary silently stops tracking the flake — the staleness the user objected to. Used only as a stop-gap while this ADR was decided. |
| Symlink `/usr/local/bin/kanata` to the store | TCC resolves symlinks; the grant is attributed to the changing store path. Already disproven in ADR-0002. |
| Ad-hoc re-sign each switch | TCC's requirement is still the cdhash, which changes with every build — the original bug. |
| Seed/update `TCC.db` directly | SIP keeps the database read-only even with Full Disk Access; not portable; the "hacking" ADR-0002 rejected. |
| Bundle (`Kanata.app`) with a fixed bundle ID | Still a physically installed copy, but adds bundling and an app lifecycle for a CLI daemon; bundle-ID keying does not remove the install step. |

## References

- kanata macOS setup: <https://github.com/jtroo/kanata/blob/main/docs/setup-macos.md>
- Implementation: `darwin/darwin.nix` (`system.activationScripts.extraActivation.text`),
  operator runbook: [`docs/troubleshooting.md`](../troubleshooting.md)
- ADR-0002 — root daemon, tray shim/helper, the original stable-copy rationale
- Evidence: tccd `Failed to match existing code requirement`; `TCC.db`
  `attempt to write a readonly database`; `tccutil: No such bundle identifier`
