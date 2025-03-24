{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./shell.nix
    ./wezterm.nix
    # Consider group dev related files, e.g. dev, direnv, git, emacs, editor
    ./dev.nix
    ./direnv.nix
    ./git.nix
    ./emacs.nix
    ./editor.nix
    ./music.nix
    ./work.nix
    ./kb.nix
    ./secretmanagement.nix
    # project specific
    ./p1.nix
    ./p2.nix
  ];

  home = {
    stateVersion = "23.11"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.
    packages = with pkgs; [
      devenv
      ltex-ls
      marksman
      nixd
      ripgrep
      tree
      # Base tooling
      drawio
      # Support to switch windows instead of apps
      # NOTE 'alt-tab-macos' not working to show multiple vivaldi windows - one of my use cases
      # TODO not working using brew instead
      # choose-gui
      # TODO Move to macosx specific ui section
      hidden-bar
    ];

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    #file = {
    #  hammerspoon = lib.mkIf pkgs.stdenvNoCC.isDarwin {
    #    source = ./../config/hammerspoon;
    #    target = ".hammerspoon";
    #    recursive = true;
    #  };
    #};

    sessionVariables = {
      # TODO Set this as part of the emacs.nix
      EDITOR = "emacs";
    };

    shellAliases = {
      "sys-rebuild" = "darwin-rebuild switch --flake ~/projects/config/dotfiles-slim --refresh";
      "sys-rollback" = "darwin-rebuild switch --rollback";
      "sys-update" =
        "cd ~/projects/config/dotfiles-slim && nix flake update && darwin-rebuild switch --flake . --refresh";
      "sys-upgrade" = "sys-update && sys-rebuild";
      "sys-optimise" = "nix-store --optimise";
    };

    # Neo2 Configuration via Karabiner Elements
    file.".config/karabiner/karabiner.json".source = ../config/karabiner/karabiner.json;
  };
}
