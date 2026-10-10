{ ... }:

{
  # Disable Slack auto-update.
  #
  # Slack 4.5x ignores the user-facing `SlackNoAutoUpdates`/`AutoUpdate` defaults;
  # its updater is only disabled through Slack's "external config". On macOS that
  # config is read from *managed (forced)* preferences via CFPreferences
  # (`CFPreferencesAppValueIsForced`), so a plain `defaults write` has no effect.
  #
  # Because our Slack lives in the read-only Nix store, Squirrel/ShipIt can never
  # install an update anyway -- it just keeps prompting. Forcing `AutoUpdate=false`
  # in the managed domain makes Slack log "updates disabled via external config",
  # sets isUpdateSupported=false and skips every update check.
  #
  # See docs/handoffs/slack-auto-update.md.
  #
  # NOTE: only the fixed set of activation scripts (preActivation,
  # extraActivation, ..., postActivation) is emitted by nix-darwin; a custom
  # `system.activationScripts.<name>` is silently ignored, so this must be added
  # to an existing entry.
  system.activationScripts.postActivation.text = ''
    managedDir="/Library/Managed Preferences"
    slackPlist="$managedDir/com.tinyspeck.slackmacgap.plist"
    tmpBase="/tmp/slack-autoupdate-$$"
    # Use bare command names: the activation script PATH already includes
    # /usr/bin:/bin:/usr/sbin:/sbin, and hardcoding BSD tool paths is brittle.
    mkdir -p "$managedDir"
    # Build a valid plist somewhere writable, then move it into the managed
    # domain directly. `defaults write /Library/Managed Preferences/...` is
    # intercepted by cfprefsd and silently dropped, so do not write there
    # directly.
    defaults write "$tmpBase" AutoUpdate -bool false
    mv -f "$tmpBase.plist" "$slackPlist"
    chown root:wheel "$slackPlist"
    chmod 644 "$slackPlist"
    # cfprefsd caches the managed domains; restart it so a relaunched Slack picks
    # up the forced value.
    killall cfprefsd 2>/dev/null || true
  '';
}
