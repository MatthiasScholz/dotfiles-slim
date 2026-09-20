{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./keyboard.nix
    ./shell.nix
    ./wezterm.nix
    ../modules/git-ai.nix
    ../modules/gws.nix
    ../modules/agentsview.nix
    # Consider group dev related files, e.g. dev, direnv, git, emacs, editor
    ./dev.nix
    ./direnv.nix
    ./git.nix
    ./emacs.nix
    ./editor.nix
    ./msg.nix
    ./music.nix
    ./graphic.nix
    ./work.nix
    ./kb.nix
    ./secretmanagement.nix
    # project specific
    ./dev.nix
    ./p1.nix
    ./p2.nix
    ./tinker.nix
    ./agentic.nix
  ];

  # Disable the Home Manager manual/manpage generation. This prevents
  # `nixosOptionsDoc` from being evaluated, which currently triggers a
  # Nix warning about `builtins.derivation` referencing the nixpkgs store
  # path without proper context (the `options.json` derivation embeds
  # declaration paths from nixpkgs source modules).
  manual.html.enable = false;
  manual.manpages.enable = false;
  manual.json.enable = false;

  # Create directories in the home folder
  # https://github.com/evantravers/dotfiles/blob/1d3bcb33707f9a36c6bc6e91767b548f4865501f/users/evantravers/home-manager.nix#L18C1-L21C5
  xdg.enable = true;
  # Disable linkApps on x86_64-darwin: nixpkgs 26.05 deprecates x86_64-darwin,
  # so lib.platforms.darwin only includes aarch64-darwin and the assertion fails.
  targets.darwin.linkApps.enable = pkgs.stdenv.hostPlatform.system == "aarch64-darwin";

  # TODO: move this to ./home-manager/modules/darwin or something - this file should be os agnostic
  xdg.configFile."hammerspoon" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    # TODO streamline configuration to config folder
    source = .config/hammerspoon;
    # FIXME not working options
    #target = ".config/hammerspoon";
    recursive = true;
  };
  #xdg.configFile."hammerspoon.hyper" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  #  # TODO streamline configuration to config folder
  #  source = .config/hammerspoon/Spoons/Hyper.spoon;
  #  # FIXME not working options
  #  #target = ".config/hammerspoon";
  #  #recursive = true;
  #};

  home = {
    stateVersion = "23.11"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.
    packages = with pkgs; [
      ltex-ls
      marksman
      nixd
      # Base tooling
      # UNUSED: drawio
      # Support to switch windows instead of apps
      # NOTE 'alt-tab-macos' not working to show multiple vivaldi windows - one of my use cases
      # TODO not working using brew instead
      # choose-gui
      # TODO Move to macosx specific ui section
      hidden-bar
      # TODO move UI stuff into a separate file
      xbar
      # Fonts
      inter
    ];

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    #file = {
    #  hammerspoon = lib.mkIf pkgs.stdenvNoCC.hostPlatform.isDarwin {
    #    source = ./../config/hammerspoon;
    #    target = ".hammerspoon";
    #    recursive = true;
    #  };
    #};

    shellAliases = {
      "sys-rebuild" = "cd ~/projects/config/dotfiles-slime && make build && make switch";
      "sys-rollback" = "cd ~/projects/config/dotfiles-slim && make rollback";
      "sys-update" = "cd ~/projects/config/dotfiles-slim && make update";
      "sys-upgrade" = "sys-update && sys-rebuild";
      # NOTE not sure which command will be more convenient, keeping duplication to experience usage pattern
      "sys-optimise" = "nix store optimise";
      "sys-cleanup" = "nix store optimise";
    };

    # TODO Have ons single place for configuration - additionally karabiner is a mac only thing
    # Neo2 Configuration via Karabiner Elements
    file.".config/karabiner/karabiner.json".source = ../config/karabiner/karabiner.json;
  };
}
