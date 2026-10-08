# Handoff: Slack auto-update deactivation

- **Status**: ✅ verified working (2026-10-08)
- **Created**: 2026-10-06
- **Updated**: 2026-10-08 (deployed and confirmed on the live machine)
- **Created by**: agent
- **Related**: `home/msg.nix`, `darwin/darwin.nix` (`postActivation`),
  commit `e84387b` (the now-reverted defaults variant)

## TL;DR

The previous `defaults`-based approaches never worked and could not work:
Slack 4.5x ignores plain `SlackNoAutoUpdates`/`AutoUpdate` defaults. Slack only
disables its updater through its **"external config"**, and on macOS that config
is read from **managed (forced)** preferences
(`CFPreferencesAppValueIsForced`). A normal `defaults write` is *not* forced, so
Slack ignored it (verified: `forced=0`).

**Fix (implemented):** force `AutoUpdate=false` as a managed preference by
writing `/Library/Managed Preferences/com.tinyspeck.slackmacgap.plist` from a
nix-darwin activation script, and drop the dead
`targets.darwin.defaults` usage from `home/msg.nix`. On next launch Slack logs
`updates disabled via external config`, sets `isUpdateSupported=false`, and skips
every update check — so no download, no ShipIt failure loop, no prompt.

## Why the old change did nothing

1. **The keys are dead.** Slack 4.51.180's `app.asar` and the bundled
   `Squirrel.framework` contain **zero** occurrences of `SlackNoAutoUpdates`. The
   `AutoUpdate` string that does exist is the name of an internal settings-schema
   field, not a macOS default.
2. **Slack gates updates on an external policy.** In `app.asar`:

   ```js
   Sb=(t,i,l)=>{
     const T=(0,oc._)().getSettingsPolicy(ys.B2), C=[], D=t==="WinStore"||t==="MAS";
     return T&&!T.value&&C.push("updates disabled via external config"), ...
   }
   ```

   `ys.B2` is the `AutoUpdate` setting (`externalName="AutoUpdate"`).
3. **On macOS the external config is a forced preference.** `oc` resolves to
   module `32614`, which uses the native `cf-prefs` addon
   (`app.asar.unpacked/node_modules/cf-prefs/build/Release/cf-prefs.node`):

   ```js
   var h = require("cf-prefs");
   a = b => h.isPreferenceForced(b) || process.env.SLACK_INTEGRATION_TEST_MODE;
   o = b => h.getPreferenceValue(b);
   E = (b, y) => { const N = y==="policy" ? (a(b.externalName) ? o(b.externalName) : undefined) : p(b.externalName); ... }
   ```

   `cf-prefs.node` calls `CFPreferencesAppValueIsForced` /
   `CFPreferencesCopyAppValue` on `CFPreferencesCurrentApplication`
   (`com.tinyspeck.slackmacgap`).

### Proof the old value was not forced

A tiny CoreFoundation probe against the live machine:

```text
AutoUpdate           forced=0 value=present      # set by HM, ignored by Slack
SlackNoAutoUpdates   forced=0 value=present      # set by HM, ignored by Slack
```

and against a real managed domain:

```text
domain=com.apple.SoftwareUpdate key=forceDelayedMajorSoftwareUpdates forced=1 value=present
domain=com.apple.applicationaccess key=allowExternalIntelligenceIntegrations forced=1 value=present
```

So keys in `/Library/Managed Preferences/*.plist` **are** treated as forced;
user/system defaults are not.

### Why the prompt kept recurring

Independently of the policy, Slack's Squirrel/ShipIt updater was trying to
replace the app in the read-only Nix store and failing:

```text
$ plutil -p ~/Library/Caches/com.tinyspeck.slackmacgap.ShipIt/ShipItState.plist
targetBundleURL => file:///nix/store/k8mxms8z.../Applications/Slack.app/

$ .../ShipIt_stderr.log.9
Installation error: ... Failed to copy bundle .../update.acVHp5l/Slack.app/
  ... NSFilePath=/nix/store/...
Resuming installation attempt 2
Resuming installation attempt 3
Too many attempts to install, aborting update
```

## What changed

### `darwin/darwin.nix` — force the managed preference

```nix
# NOTE: nix-darwin only emits a fixed set of activation scripts; a custom
# `system.activationScripts.slackNoAutoUpdate` is silently ignored, so this is
# appended to `postActivation` instead.
system.activationScripts.postActivation.text = ''
  managedDir="/Library/Managed Preferences"
  slackPlist="$managedDir/com.tinyspeck.slackmacgap.plist"
  tmpBase="/tmp/slack-autoupdate-$$"
  # Bare command names are intentional: the activation PATH already includes
  # /usr/bin:/bin:/usr/sbin:/sbin, and hardcoding BSD tool paths is brittle.
  mkdir -p "$managedDir"
  # Build a valid plist somewhere writable, then move it into the managed
  # domain directly: `defaults write /Library/Managed Preferences/...` is
  # intercepted by cfprefsd and silently dropped.
  defaults write "$tmpBase" AutoUpdate -bool false
  mv -f "$tmpBase.plist" "$slackPlist"
  chown root:wheel "$slackPlist"
  chmod 644 "$slackPlist"
  # cfprefsd caches the managed domains; restart it so a relaunched Slack sees it.
  killall cfprefsd 2>/dev/null || true
'';
```

This replaces the old `postActivation.text` hunk that wrote
`/Library/Preferences/...` (a non-forced, ignored location).

**Deploy gotchas hit while landing this:**

1. `system.activationScripts.slackNoAutoUpdate.text` is **never executed**.
   nix-darwin's `modules/system/activation-scripts.nix` builds `activate` by
   interpolating only `preActivation`, `extraActivation`, `groups`, `users`, …,
   `postActivation`; any other attribute is silently dropped. Put custom work in
   one of those (`postActivation` here).
2. Hardcoding BSD tool paths is brittle: `chown` lives in `/usr/sbin`, not
   `/usr/bin`, and the bad guess aborted activation under `set -e`. The
   activation script already seeds `PATH` with `/usr/bin:/bin:/usr/sbin:/sbin`,
   so bare command names are correct and portable.
3. `defaults write /Library/Managed Preferences/<domain>` exits 0 but does not
   persist (cfprefsd intercepts managed-domain writes). Write a plist to `/tmp`
   and `mv` it into place instead.
4. This macOS ships no `profiles install` verb, so a configuration profile is
   not scriptable here — the direct managed-plist write is the only local path.

### `home/msg.nix` — drop the dead defaults

The `targets.darwin.defaults."com.tinyspeck.slackmacgap"` block is removed. It was
ignored **and** it broke evaluation of the x86_64 `MacPro` profile
(`targets.darwin.defaults` asserts `aarch64-darwin`).

## Verification

**Confirmed on 2026-10-08** after `make setup` + Slack restart:

```text
$ plutil -p "/Library/Managed Preferences/com.tinyspeck.slackmacgap.plist"
{ "AutoUpdate" => false }

$ /tmp/force2 com.tinyspeck.slackmacgap AutoUpdate
forced=1 value=present

$ grep -A6 'getIsUpdateSupported' ~/Library/Application\ Support/Slack/logs/default/browser.log
[10/08/26, 21:18:23:119] info: getIsUpdateSupported: Updates are supported      # before
[10/08/26, 21:56:17:769] info: getIsUpdateSupported: Updates are not supported  # after restart
  { "version": "4.51.180",
    "reasons": [ "updates disabled via external config" ],
    "distribution": "DDL", ... }
```

ShipIt is no longer invoked (no new `ShipIt_stderr.log*`, `ShipItState.plist`
unchanged since before the restart, no `ShipIt` process).

Manual steps (for reference) are below.

---

After `make setup` (activates the managed plist) and a Slack restart:

1. Confirm the forced value:

   ```bash
   /tmp/forcecheck   # rebuilt helper, or:
   plutil -p "/Library/Managed Preferences/com.tinyspeck.slackmacgap.plist"   # { AutoUpdate => 0 }
   ```

2. Confirm Slack noticed. Slack logs to
   `~/Library/Application Support/Slack/logs/`; look for:

   ```text
   getIsUpdateSupported: Updates are not supported
     { reasons: [ "updates disabled via external config" ] }
   ```

3. Confirm the update path stops. Quit and relaunch Slack and leave it running;
   verify ShipIt is no longer invoked:

   ```bash
   ls -lat ~/Library/Caches/com.tinyspeck.slackmacgap.ShipIt/
   ```

   `ShipItState.plist` should no longer be rewritten.

4. The aarch64 profile still evaluates:

   ```bash
   nix eval --raw '.#darwinConfigurations.Matthiass-MacBook-Pro.config.system.build.toplevel.drvPath'
   ```

## Remaining, unrelated issue (not caused by this fix)

`MacPro` still fails to evaluate, but no longer because of Slack. The old
`targets.darwin.defaults` assertion is gone; the next error is the nix-darwin
version guard:

```text
nix-darwin now uses release branches that correspond to Nixpkgs releases.
The nix-darwin and Nixpkgs branches in use must match, but you are currently
using nix-darwin 26.11 with Nixpkgs 26.05.
```

`flake.nix` pins `MacPro` to `nixpkgs-26_05` while the `darwin` input is
`github:LnL7/nix-darwin` (26.11). Fixing that requires a matching nix-darwin
input for the Intel machine and is out of scope here.

## Fallback if the managed-preference fix ever regresses

Patch `app.asar` so Slack's `should-i-update` query fails (Slack maps a failed
query to `update_available:false`, so it never downloads). This is more invasive:

- `app.asar` has both per-file `hash`/`blocks` integrity **and** a header hash in
  `Info.plist` (`ElectronAsarIntegrity`), both validated because the
  `EnableEmbeddedAsarIntegrityValidation` fuse is **enabled**.
- Modifying the bundle invalidates the arm64 code signature; the app is then
  **SIGKILLed** (`Killed: 9`), so it must be ad-hoc re-signed
  (`codesign --force --deep --sign -`), which in turn changes the code identity
  and forces macOS to re-grant TCC permissions (camera/mic/screen recording).
- Concrete targets, if needed: file `dist/main.bundle.cjs` contains
  `/desktop/update/v2/should-i-update`; recompute that file's `hash`/`blocks` and
  the Info.plist header hash.

Because of the re-signing/TCC cost, prefer the managed-preference fix.

## References

- Implementation: `darwin/darwin.nix` (`postActivation`), `home/msg.nix`.
- Slack internals: `app.asar` `Sb` / `getSettingsPolicy`; module `32614`
  (`cf-prefs`); `app.asar.unpacked/node_modules/cf-prefs`.
- Live evidence: `~/Library/Caches/com.tinyspeck.slackmacgap.ShipIt/`,
  `/Library/Managed Preferences/`.
- Commits: `e84387b` introduced the now-reverted `home/msg.nix` defaults.
