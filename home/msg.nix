{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    discord
    teams
    slack
  ];

  # Slack auto-update is disabled system-wide via a *forced* managed preference
  # (the only mechanism Slack 4.5x honours); see darwin/slack.nix
  # (`postActivation`) and docs/handoffs/slack-auto-update.md. The user-facing
  # `targets.darwin.defaults` keys are ignored by Slack and also break
  # evaluation of the x86_64 MacPro profile.
}
