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

  # NOTE Disable Slack Auto Updates which leads to annoying ui permission requests
  targets.darwin.defaults."com.tinyspeck.slackmacgap" = {
    AutoUpdate = false;
    SlackNoAutoUpdates = true;
  };

}
