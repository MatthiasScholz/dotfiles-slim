{ pkgs, ... }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    home-manager
    # System Status
    # TODO export configuration and add to this repository - including restore
    # FIXME broken stats
  ];

  /*
    FIXME broken 2025-08-11
    # Get ollama launched
    # TODO move to kb.nix
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
  */

  # Use a custom configuration.nix location.
  # TODO keep the default location to support use of `topgrade`
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  environment.darwinConfig = "$HOME/project/config/dotfiles-slim";
  #environment.darwinConfig = "$HOME/.config/nixpkgs/darwin";

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs = {
    gnupg.agent.enable = true;
    # FIXME nh was not found when trying to innstall
    # nh = {
    #   enable = true;
    #   #clean.enable = true;
    #   #clean.extraArgs = "--keep-since 4d --keep 3";
    #   #flake = "/home/matthias/config/dotfiles-slim/"; # sets NH_OS_FLAKE variable for you
    # };
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  # system.stateVersion = 6;

  # TODO Make customized screenshot shortcut declarative
  # - default to clipboard instead to file
  # -> https://www.reddit.com/r/NixOS/comments/17n3tcn/setting_keyboard_shortcuts_in_nix_darwin/

  fonts.packages = [
    pkgs.atkinson-hyperlegible
    # FIXME BROKEN since 2026-02-27 pkgs.jetbrains-mono
  ];

  services = {
    # FIXME not working
    #karabiner-elements = {
    #  enable = true;
    #};

    /*
      NOTE unused, unconfigured
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
    */
    /*
      yabai = {
        enable = true;
        config = {
          layout = "float";
        };
      };
    */
    /*
      NOTE unused, not working as expected
         TODO be able to create a window static window placement which support macos screens or 3 finger swip
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
          ctl - k : bash -c "$HOME/projects/config/dotfiles-slim/config/windowswitcher/switch.sh"

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
    */
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
      appswitcher-all-displays = true;
    };

    # "Displays have separate Spaces"
    # false = each physical display has a separate space (enables Dock on all screens)
    # true = one space spans across all physical displays (disables Dock on secondary screens)
    spaces.spans-displays = false;

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
    # Hammerspoon configuration
    CustomUserPreferences."org.hammerspoon.Hammerspoon" = {
      MJConfigFile = "~/.config/hammerspoon/init.lua";
    };
  };
}
