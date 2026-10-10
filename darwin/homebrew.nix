{ config, ... }:

{
  # TODO Understand if there is potential to overwrite - since assignment is used
  # FIXME have homebrew bin in shell
  #programs.zsh.initContent = ''
  #  export PATH="$\{PATH\}:/opt/homebrew/bin"
  # '';

  homebrew = {
    # NOTE Enabling this option does not install Homebrew, see the Homebrew website for installation instructions.
    enable = true;
    global.autoUpdate = true;

    # SEE: https://daiderd.com/nix-darwin/manual/index.html#opt-homebrew.onActivation
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    # Derive tap names from nix-homebrew.taps to stay in sync (single source of truth).
    # See: https://github.com/zhaofengli/nix-homebrew#optional-align-homebrew-taps-config-with-nix-homebrew
    # Homebrew normalizes "homebrew/homebrew-core" to "homebrew/core" internally, so
    # the full names passed via builtins.attrNames work correctly in the Brewfile.
    taps = builtins.attrNames config.nix-homebrew.taps;

    brews = [
      # TODO find a way to install packages using go get - reduce brew usage
      # FIXME Error: Refusing to load formula clok/sm/sm from untrusted tap clok/sm.
      #       Run `brew trust --formula clok/sm/sm` or `brew trust clok/sm` to trust it.
      # "sm"
      # FIXME Error like above
      # "gossm"
      # Make vterm work on emacs
      #      https://docs.doomemacs.org/v21.12/modules/term/vterm/
      # TODO Check if needed
      "libvterm" # doomemacs vterm requirement
      # TODO Migrate to package management once the package is fixed
      # FIXME Migrate to hammerspoon choose-gui not available on MacPro due to older MacOS
      "choose-gui"
      # TODO move into a template/aws fake - but curently no package
      # FIXME Error like above
      # "awslim"
      # Shell debugger
      # https://bashdb.readthedocs.io/en/latest/entry-exit.html
      "bashdb"
      # https://zshdb.readthedocs.io/en/latest/entry-exit.html
      "zshdb"
      # FIXME opa broken nix package on darwin
      "opa"
      # Management of Kanata via tray icon
      "kanata-tray"
    ];

    casks = [
      # TODO Migrate to nixpkgs _1password-gui when package is not broken anymore
      "1password"
      # OLD "beeper"
      "disk-inventory-x"
      "google-drive"
      # TODO Migrate to nixpkgs
      # TODO sundown in case kanata works nicely
      "karabiner-elements"
      "raycast"
      "hammerspoon"
      # TODO Migrate to nixpkgs
      #"wezterm"
      "vivaldi"
      # aws specific tooling - currently unsupported package
      # TODO Migrate to knowledge management: kb.nix
      "notion"
      # FIXME "calibre"
      # TODO move to project specific tools
      #"mattermost"
      # TODO Check if it can be replaced with the nixpkgs
      # UNNEEDED "microsoft-teams"
      # System cleanup for manual tools
      # NOTE try using nix capabilities as much as possible
      "appcleaner"
      # AI
      # https://openchamber.dev — desktop app, installed here by Homebrew but
      # run as a *client* of the Nix-managed `programs.openchamber` server
      # (client mode is enabled in home/agentic.nix; see ADR-0008).
      "openchamber"
      # https://msty.app
      # TODO Migrate to knowledge management: kb.nix
      # UNUSED "msty"
      # NOTE unauthorized "hermes-desktop"
      # TODO try to get skhd working
      "icanhazshortcut"
      # Keyboard Configuration Management
      # UNUSED "vial"
      # TODO separate personal stuff
      # Thinkering
      "orcaslicer"
      # UNUSED "freecad"
      # FIXME "raspberry-pi-imager"
      # FIXME move back to nixpkgs once more recent version is publish > 7
      "zoom"
      # Better Alt Tab Handling
      # https://github.com/rokartur/BetterCmdTab
      "bettercmdtab"
    ];

    masApps = {
      # FIXME failure: "The installation could not be started"
      # "1Password for Safari" = 1569813296;
      "Bandwidth+" = 490461369;
      "Kindle Classic" = 405399194;
      # FIXME failure: "The installation could not be started"
      # "Kindle" = 302584613;
      "Meeter" = 1510445899;
      # FIXME add latest tool:
      # "System Color Picker" = ???;
      # "MQTT Explorer" = ???;
    };
  };
}
