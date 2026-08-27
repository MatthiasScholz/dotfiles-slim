{
  config,
  pkgs,
  ...
}:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    home-manager
    # System Status
    # TODO export configuration and add to this repository - including restore
    # FIXME broken stats
  ];

  # Declaratively create /etc/nix/nix.custom.conf for Determinate Nix
  environment.etc."nix/nix.custom.conf".text = ''
    # This configuration is necessary to allow the user to use binary caches
    # like the one required by devenv (Cachix) without being root.
    # We include root and for safety and system function.
    # Used by https://github.com/DeterminateSystems/nix-installer.

    eval-cores = 0

    #alternative, less secure
    #trusted-users = root ${config.system.primaryUser}

    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=
  '';
  # ----------------------------------------------------------------------

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

  # Auto upgrade nix package and the daemon service.
  nix = {
    # NOTE using determine to manage the nix installation which handles nix updates with a separate daemon.
    # SEE https://determinate.systems/posts/changelog-determinate-nix-342/
    enable = false;

    # TODO understand if this is still needed with using determine installer
    package = pkgs.nix;
  };

  # TODO Move to emacs or shell since it is connected to direnv
  # https://docs.doomemacs.org/v21.12/modules/tools/direnv/
  # NOTE disabled since it requires nix.enable
  # services.lorri.enable = true;

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

  # TODO Understand if there is potential to overwrite - since assignment is used
  # FIXME have homebrew bin in shell
  #programs.zsh.initContent = ''
  #  export PATH="$\{PATH\}:/opt/homebrew/bin"
  # '';

  # Storage optimisation
  # Keeping /nix/store tidy
  # https://nixos.wiki/wiki/Storage_optimization
  # FIXME should be os independent
  nix.extraOptions = ''
    auto-optimise-store = true
  '';

  # NOTE not working because of determined-nix usage
  # - nix.optimise.automatic requires nix.enable
  # - nix.gc.automatic requires nix.enable
  # nix.gc = {
  #   automatic = true;
  #   dates = "weekly";
  #   options = "--delete-older-than 14d";
  # };
  # nix.optimise = {
  #   automatic = true;
  #   dates = [ "weekly" ];
  # };

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
      # https://msty.app
      # TODO Migrate to knowledge management: kb.nix
      # UNUSED "msty"
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

  # Neo2 Keyboard Layout
  # NOTE Migrated to Kanata
  # needs additional configuration of karabiner-elements as part of home-manager /home/home.nix
  # https://github.com/Cu3PO42/gleaming-glacier/blob/5abb8c0a3fb72cafbc7ca113e5f135142d0b51c8/modules/darwin/neo2/default.nix#L9
  # https://github.com/Cu3PO42/gleaming-glacier/blob/5abb8c0a3fb72cafbc7ca113e5f135142d0b51c8/config/karabiner/LICENSE.md?plain=1
  system.activationScripts.extraActivation.text =
    let
      user = config.system.primaryUser;
      home = config.users.users.${user}.home;
      kanataTrayConfig = pkgs.writeText "kanata-tray.toml" (
        builtins.replaceStrings [ "/Users/matthias" ] [ home ] (
          builtins.readFile ../config/kanata/kanata-tray.toml
        )
      );
    in
    ''
      echo "INFO :: Copying Neo layout into system wide folder"
      cp -f ${../config/karabiner/neo.icns} "/Library/Keyboard Layouts/neo.icns"
      cp -f ${../config/karabiner/neo.keylayout} "/Library/Keyboard Layouts/neo.keylayout"

      # Kanata Configuration
      # TODO Check if there is a better approach than using cp - via homemanager
      echo "INFO :: Copying Kanata layout into system wide folder"
      mkdir -p "${home}/Library/Application Support/kanata/"
      cp -f ${../config/kanata/basbousa.kbd} "${home}/Library/Application Support/kanata/kanata.kbd"

      # .Kanata Tray Autostart Configuration
      # Configure launchctl
      # -> https://github.com/rszyma/kanata-tray/issues/67#issuecomment-3172766036
      mkdir -p "${home}/Library/Application Support/kanata-tray/"
      # TODO Check if files gets updated properly
      cp -f ${kanataTrayConfig} "${home}/Library/Application Support/kanata-tray/kanata-tray.toml"

      # sudoers entry for kanata-tray wrapper script (NOPASSWD for staff group).
      # The wrapper at /opt/homebrew/Cellar/kanata-tray/0.8.0/bin/kanata-tray
      # delegates to kanata-tray.real for normal operation, and also provides
      # helper subcommands: --install-karabiner-dk, --kill-manual-daemon,
      # --clear-logs, --bootstrap-only, --check-socket, --test-kanata.
      echo "%staff ALL=(root:wheel) NOPASSWD:SETENV: /opt/homebrew/Cellar/kanata-tray/0.8.0/bin/kanata-tray.real" | sudo tee /private/etc/sudoers.d/kanata-tray

      # === Create stable symlink for kanata binary ===
      # The root LaunchDaemon references /Applications/kanata (not the nix store
      # path) so the config is stable across nix rebuilds. The symlink is
      # recreated on every activation to point at the current nix store path.
      # TCC is not required (system LaunchDaemons bypass it), but the stable
      # path keeps the config consistent if the architecture ever changes back
      # to a user-spawned kanata.
      # Ref: https://github.com/ryoppippi/dotfiles (commit 11088b4)
      echo "INFO :: Creating stable kanata symlink at /Applications/kanata"
      ln -sf "${pkgs.kanata}/bin/kanata" "/Applications/kanata"
    '';

  launchd = {
    # === karabiner-dk system daemon (protocol fix for nix kanata) ===
    #
    # PROTOCOL COMPATIBILITY FIX:
    #   nix kanata v1.12.0 communicates with the virtual HID daemon using
    #   pqrs::local_datagram (SOCK_DGRAM) over a Unix domain socket.
    #   The homebrew Karabiner-Elements daemon uses pqrs::unix_domain_stream
    #   (SOCK_STREAM). These are INCOMPATIBLE — nix kanata cannot talk to the
    #   homebrew daemon and fails with a connection error.
    #
    #   Solution: Use nix `karabiner-dk` v6.6.0, which uses local_datagram
    #   (SOCK_DGRAM), matching nix kanata's protocol. This system daemon
    #   provides the DriverKit virtual HID device and a root-only SOCK_DGRAM
    #   socket that nix kanata connects to.
    #
    # WHY KANATA RUNS AS A SEPARATE ROOT LAUNCHDAEMON (not spawned by kanata-tray):
    #   1. Karabiner's vHID socket lives in a root-only directory
    #      (/Library/Application Support/org.pqrs/tmp/rootonly/), so kanata must
    #      run as root to open the virtual HID device.
    #   2. kanata-tray drops privileges to the user before spawning, which breaks
    #      vHID access. Re-elevating via a sudo wrapper spawns kanata as root but
    #      WITHOUT a GUI session, so the macOS TCC Accessibility prompt cannot be
    #      shown and kanata fails to grab the keyboard.
    #   Solution: Run kanata as a root LaunchDaemon. System LaunchDaemons bypass
    #   TCC entirely and can access the root-only vHID socket directly.
    #
    # ARCHITECTURE:
    #   1. karabiner-dk system daemon (root): provides the DriverKit virtual HID
    #      device and the SOCK_DGRAM socket at:
    #      /Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server/*.sock
    #   2. kanata system daemon (root): connects to the virtual HID device via the
    #      socket above. Uses stable symlink /Applications/kanata → nix store path.
    #      Created by activation script: ln -sf ${pkgs.kanata}/bin/kanata /Applications/kanata
    #   3. kanata-tray user agent (user context): GUI tray app that connects to
    #      kanata via TCP (port 5829) for on/off/layer/preset control. It does NOT
    #      spawn kanata (autorun=false in kanata-tray.toml).
    #
    # MACOS ACCESSIBILITY (TCC):
    #   Not required for the root LaunchDaemon (system daemons bypass TCC).
    #   The stable symlink /Applications/kanata is kept for consistency but is not
    #   strictly necessary for TCC anymore.
    #
    # NOTE: After `make setup`, both system daemons start automatically on boot.
    #       The nix-generated plists replace any manually-installed versions.
    daemons = {
      karabiner-dk = {
        # The nix store path contains "Application Support" (with a space).
        # nix-darwin wraps command in: /bin/sh -c "/bin/wait4path /nix/store && <command>"
        # Single-quote the path so the shell treats it as a single word.
        command = "'${pkgs.karabiner-dk}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon'";
        serviceConfig = {
          Label = "com.karabiner.VirtualHIDDevice-Daemon";
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/tmp/karabiner-dk.out.log";
          StandardErrorPath = "/tmp/karabiner-dk.err.log";
        };
      };
    };
    # kanata runs as a root LaunchDaemon to access the Karabiner-VirtualHIDDevice
    # IPC socket at /Library/Application Support/org.pqrs/tmp/rootonly/.
    # Running as a user agent blocks access to this root-only directory.
    daemons = {
      kanata = {
        # Runs kanata as a root LaunchDaemon via nix-darwin.
        # This gives it access to the Karabiner Virtual HID Device IPC socket
        # at /Library/Application Support/org.pqrs/tmp/rootonly/.
        # The karabiner-dk daemon must be running and approved in System Settings.
        command = "/Applications/kanata -c '${
          config.users.users.${config.system.primaryUser}.home
        }/Library/Application Support/kanata/kanata.kbd' --port 5829";
        serviceConfig = {
          Label = "com.kanata";
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/tmp/kanata.out.log";
          StandardErrorPath = "/tmp/kanata.err.log";
        };
      };
    };
  };

}
