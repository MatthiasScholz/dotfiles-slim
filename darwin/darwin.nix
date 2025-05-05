{
  # unused: config,
  pkgs,
  ...
}:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    home-manager
    # Local LLMs
    ollama
    # System Status
    # TODO export configuration and add to this repository - including restore
    stats
  ];

  # Get ollama launched
  # https://www.danielcorin.com/til/nix-darwin/launch-agents/
  # TODO Move to kb.nix or consider connection if os independency should be achieved
  # Creates a plist file at `~/Library/LaunchAgents``
  # State: `launchctl blame gui/501/org.nixos.ollama-serve`
  launchd = {
    user = {
      agents = {
        ollama-serve = {
          command = "${pkgs.ollama}/bin/ollama serve";
          serviceConfig = {
            KeepAlive = true;
            RunAtLoad = true;
            StandardOutPath = "/tmp/ollama.out.log";
            StandardErrorPath = "/tmp/ollama.err.log";
            EnvironmentVariables = {
              OLLAMA_ORIGINS = "moz-extension://*,chrome-extension://*,safari-web-extension://*";
            };
          };
        };
      };
    };
  };

  # Use a custom configuration.nix location.
  # TODO keep the default location to support use of `topgrade`
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  environment.darwinConfig = "$HOME/project/config/dotfiles-slim";
  #environment.darwinConfig = "$HOME/.config/nixpkgs/darwin";

  # Auto upgrade nix package and the daemon service.
  nix = {
    package = pkgs.nix;
    settings = {
      "extra-experimental-features" = [
        "nix-command"
        "flakes"
      ];
      "trusted-users" = [
        # FIXME make dependent to the user name configuration - do not hard-code
        "matthias"
      ];
    };
  };

  # TODO Move to emacs or shell since it is connected to direnv
  # https://docs.doomemacs.org/v21.12/modules/tools/direnv/
  services.lorri.enable = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs = {
    gnupg.agent.enable = true;
    zsh.enable = true; # default shell on catalina
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # TODO Make customized screenshot shortcut declarative
  # - default to clipboard instead to file
  # -> https://www.reddit.com/r/NixOS/comments/17n3tcn/setting_keyboard_shortcuts_in_nix_darwin/

  fonts.packages = [
    pkgs.atkinson-hyperlegible
    pkgs.jetbrains-mono
  ];

  services = {
    # FIXME not working
    #karabiner-elements = {
    #  enable = true;
    #};

    # https://felixkratz.github.io/SketchyBar/
    # https://mynixos.com/nix-darwin/options/services.sketchybar
    sketchybar = {
      enable = true;
      # https://mynixos.com/nix-darwin/option/services.sketchybar.config
      config = ''
        sketchybar --bar height=24
        sketchybar --update
        echo "sketchybar configuration loaded.."
      '';
      extraPackages = [
        pkgs.jq
        pkgs.lua
      ];
    };
    # Window Manager
    yabai = {
      enable = true;
      config = {
        layout = "float";
        mouse_modifier = "ctrl";
        mouse_action1 = "resize";
        mouse_drop_action = "stack";
        window_gap = "20";
        window_border = "off";
        window_opacity = "off";
        window_shadow = "off";
        # sketchybar awarness
        # 24: height of sketchybar
        external_bar = "all:24:0";
      };
      extraConfig = ''
        yabai -m rule --add app='Spotify' display=east

        yabai -m rule --add app='System Settings' manage=off

        # Space positioning
        yabai -m rule --add app="^Google Calendar" space=1
        yabai -m rule --add app="^Obsidian" space=3
        yabai -m rule --add app="^Vivaldi" space=4
        yabai -m rule --add app="^Emacs" space=5
        yabai -m rule --add app="^Slack" space=6
        yabai -m rule --add app="^Microsoft Teams" space=6
        yabai -m rule --add app="^Google Chat" space=6
        yabai -m rule --add app="^Zoom" space=6
        yabai -m rule --add app="^Kindle" space=7
        yabai -m rule --add app="^Warp" space=7
        yabai -m rule --add app="^Msty" space=7
        yabai -m rule --add app="^Activity Monitor" space=7
        yabai -m rule --add app="^Notion" space=8
        yabai -m rule --add app="^Beeper" space=9
      '';
    };
    # Keyboard Shortcut Manager
    skhd = {
      enable = true;
      # FIXME use a different path, this is only for testing
      # FIXME none of the commands are working
      skhdConfig = ''
        ctl - k : bash -c "/Users/matthias/projects/config/dotfiles-slim/config/windowswitcher/switch.sh"

        # select window
        alt + cmd - w: yabai -m query --windows \
        | jq -r '.[] | "\(.app): \(.title)"' \
        | /opt/homebrew/bin/choose -u -b fabd2f -c 427b58 -s 14 -n 15 -i "$@" <&0 \
        | yabai -m query --windows \
        | jq ".[$idx].id" \
        | xargs yabai -m window --focus

        # cycle between stacked windows
        alt + cmd - j : yabai -m query --spaces --space \
        | jq -re ".index" \
        | xargs -I{} yabai -m query --windows --space {} \
        | jq -sre 'add | map(select(."is-minimized"==false)) | sort_by(.display, .frame.y, .frame.x, .id) | . as $array | length as $array_length | index(map(select(."has-focus"==true))) as $has_index | if $has_index > 0 then nth($has_index - 1).id else nth($array_length - 1).id end' \
        | xargs -I{} yabai -m window --focus {}

        alt + cmd - k : yabai -m query --spaces --space \
        | jq -re ".index" \
        | xargs -I{} yabai -m query --windows --space {} \
        | jq -sre 'add | map(select(."is-minimized"==false)) | sort_by(.display, .frame.y, .frame.x, .id) | . as $array | length as $array_length | index(map(select(."has-focus"==true))) as $has_index | if $array_length - 1 > $has_index then nth($has_index + 1).id else nth(0).id end' \
        | xargs -I{} yabai -m window --focus {}
      '';
    };
  };

  # TODO Understand if there is potential to overwrite - since assignment is used
  # FIXME have homebrew bin in shell
  #programs.zsh.initContent = ''
  #  export PATH="$\{PATH\}:/opt/homebrew/bin"
  # '';

  # Storage optimisation
  # https://nixos.wiki/wiki/Storage_optimization
  # TODO should be os independent
  # NOTE disabled because of issue: https://github.com/NixOS/nix/issues/7273
  nix.extraOptions = ''
    auto-optimise-store = false
  '';

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

    # TODO probably have to be managed via nix-homebrew
    #taps = [
    #  "gjbae1212/gossm"
    #];

    brews = [
      # TODO find a way to install packages using go get - reduce brew usage
      "sm"
      "gossm"
      # Emacs support :lang markdown
      "grip"
      # Make vterm work on emacs
      #      https://docs.doomemacs.org/v21.12/modules/term/vterm/
      "libvterm" # doomemacs vterm requirement
      # TODO Migrate to package management once the package is fixed
      "choose-gui"
      # TODO move into a template/aws fake - but curently no package
      "awslim"
      # emacs
      # NOTE only via cli, problems with the clipboard - fallback
      # "emacs"
      #{
      #  name = "emacs-plus";
      #  args = [
      #    "with-xwidgets"
      #    "with-imagemagick"
      #  ];
      #  start_service = true;
      #  restart_service = "changed";
      #}
      # NOTE only 29.1
      #{
      #  name = "emacs-mac";
      #  args = [ "with-modules" ];
      #}
      #"libgccjit"
      # FIXME find out how to install with parameters
      #"emacs-mac --with-modules --with-xwidgets"
      # Shell debugger
      # https://bashdb.readthedocs.io/en/latest/entry-exit.html
      "bashdb"
      # https://zshdb.readthedocs.io/en/latest/entry-exit.html
      "zshdb"
    ];

    casks = [
      # TODO Migrate to nixpkgs _1password-gui when package is not broken anymore
      "1password"
      "beeper"
      "disk-inventory-x"
      # TODO Migrate to nixpkgs
      "karabiner-elements"
      "raycast"
      # TODO Migrate to nixpkgs
      #"wezterm"
      "vivaldi"
      # aws specific tooling - currently unsupported package
      # TODO Migrate to knowledge management: kb.nix
      # TODO Migrate to engagement specific stuff
      # TODO how to install the plugins for logseq?
      #"logseq"
      "obsidian"
      "notion"
      # TODO move to project specific tools
      #"mattermost"
      # TODO Check if it can be replaced with the nixpkgs
      "microsoft-teams"
      # TODO separate personal stuff
      "orcaslicer"
      "raspberry-pi-imager"
      # System cleanup for manual tools
      # NOTE try using nix capabilities as much as possible
      # "app-cleaner"
      # AI
      # https://msty.app
      # TODO Migrate to knowledge management: kb.nix
      "msty"
      # TODO try to get skhd working
      "icanhazshortcut"
      # NOTE not available as nixpkgs anymore
      "zoom"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "Bandwidth+" = 490461369;
      "Kindle Classic" = 405399194;
      "Kindle" = 302584613;
      "Meeter" = 1510445899;
    };
  };

  # Enable sudo authentication with Touch ID.
  # https://daiderd.com/nix-darwin/manual/index.html#opt-security.pam.services.sudo_local.enable
  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    dock = {
      autohide = true;
      orientation = "left";
      show-process-indicators = false;
      show-recents = false;
      static-only = true;
      # Disable automatically rearrange spaces based on most recent use
      # https://daiderd.com/nix-darwin/manual/index.html#opt-system.defaults.dock.mru-spaces
      mru-spaces = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXEnableExtensionChangeWarning = false;
    };
    NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      "com.apple.keyboard.fnState" = true;
      NSAutomaticWindowAnimationsEnabled = false;
      # avoid adding a period when pressing space bar two times
      # https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-system.defaults.NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled
      NSAutomaticPeriodSubstitutionEnabled = false;
    };
  };

  # Neo2 Keyboard Layout
  # needs additional configuration of karabiner-elements as part of home-manager /home/home.nix
  # https://github.com/Cu3PO42/gleaming-glacier/blob/5abb8c0a3fb72cafbc7ca113e5f135142d0b51c8/modules/darwin/neo2/default.nix#L9
  # https://github.com/Cu3PO42/gleaming-glacier/blob/5abb8c0a3fb72cafbc7ca113e5f135142d0b51c8/config/karabiner/LICENSE.md?plain=1
  system.activationScripts.extraActivation.text = ''
    echo "INFO :: Copying Neo layout into system wide folder"
    cp ${./neo.icns} "/Library/Keyboard Layouts/neo.icns"
    cp ${./neo.keylayout} "/Library/Keyboard Layouts/neo.keylayout"
  '';

}
