{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # TODO Find a way to manage these "globally" but outside of dotfiles-slim repository.
    # NOTE MS Teams nixpkgs outdated and broken -> use brew
    # teams
    # Slack
    # slack
    # VPN client
  ];

}
