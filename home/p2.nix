{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # TODO Find a way to manage these "globally" but outside of dotfiles-slim repository.
    # teams
    # Slack
    # slack
    # VPN client
  ];

}
