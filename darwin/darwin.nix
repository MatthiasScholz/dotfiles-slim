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

      # === Stable copy of the kanata binary (TCC requirement) ===
      # /usr/local/bin/kanata must be a REAL FILE COPY, never a symlink:
      # macOS TCC resolves symlinks and attributes its Input Monitoring check
      # to the real executable path (/nix/store/.../bin/kanata), which changes
      # on every rebuild and thereby invalidated the permission on every nix
      # update. A copy at a stable path keeps the grant valid.
      # Ref: https://github.com/jtroo/kanata/blob/main/docs/setup-macos.md
      echo "INFO :: Copying kanata binary to stable path /usr/local/bin/kanata"
      mkdir -p /usr/local/bin /usr/local/libexec
      cp -f "${pkgs.kanata-with-cmd}/bin/kanata" /usr/local/bin/kanata
      rm -f /Applications/kanata

      # === kanata-tray lifecycle shim + privileged helper ===
      # kanata-tray (GitHub rszyma/kanata-tray) is hardcoded to SPAWN and OWN
      # the kanata process (runner.Run -> exec.CommandContext -> cmd.Wait).
      # It has no "monitor external kanata" mode. A user-spawned kanata cannot
      # work (Karabiner vHID socket lives under a root-only dir), while the
      # root daemon CAN (TCC granted, see launchd.daemons.kanata).
      # Solution: the tray manages a lifecycle TWIN instead of kanata itself:
      #   1. shim (/usr/local/bin/kanata-tray-shim, started by the tray):
      #      starts the root kanata LaunchDaemon via the helper, then mirrors
      #      its liveness by watching the kanata TCP port; exits when kanata
      #      stops, so the tray icon reflects the REAL daemon state.
      #   2. helper (/usr/local/libexec/kanata-manage, root-owned): the ONE
      #      command that may stop/start the system daemon. Requires a narrow
      #      NOPASSWD sudoers rule, because a user agent has no other way to
      #      control a root LaunchDaemon. Paths are version-independent, so
      #      this survives nix/brew updates (no versioned paths, no Cellar
      #      wrapper hacks like the previous setup).
      echo "INFO :: Installing kanata tray lifecycle shim"
      cat > /usr/local/bin/kanata-tray-shim <<'SHIM'
#!/bin/bash
# Lifecycle twin of the root kanata LaunchDaemon for kanata-tray.
# Started by kanata-tray as the preset process; daemon is managed via the
# privileged helper. Exits when the kanata TCP port stops listening.

sudo -n /usr/local/libexec/kanata-manage start

# Wait for the daemon's TCP port (it takes a few seconds to start).
# Will exit non-zero if it never comes up (tray marks preset crashed).
up=0
for _ in $(seq 1 15); do
  if nc -z 127.0.0.1 5829 2>/dev/null; then
    up=1
    break
  fi
  sleep 1
done
if [ "$up" = 0 ]; then
  echo "kanata TCP port did not come up" >&2
  exit 1
fi

# Mirror liveness; tolerate short TCP outages (e.g. daemon self-reload).
while sleep 1; do
  down=0
  for _ in $(seq 1 5); do
    if nc -z 127.0.0.1 5829 2>/dev/null; then
      down=0
      break
    fi
    down=$((down + 1))
    sleep 1
  done
  if [ "$down" -ge 5 ]; then
    exit 0
  fi
done
SHIM
      chmod 755 /usr/local/bin/kanata-tray-shim

      cat > /usr/local/libexec/kanata-manage <<'HELPER'
#!/bin/bash
# Start/stop the root kanata LaunchDaemon (called via sudo by the shim).
# Deliberately restricted to start/stop only.
PLIST=/Library/LaunchDaemons/com.kanata.plist
case "$1" in
  start)
    launchctl enable system/com.kanata
    launchctl bootstrap system "$PLIST" 2>/dev/null || true
    # Only start if not already running; a kickstart -k would flap the TCP
    # port (kanata needs ~2s to re-listen) and destabilize the tray.
    if ! launchctl print system/com.kanata 2>/dev/null | grep -q "state = running"; then
      launchctl kickstart system/com.kanata
    fi
    ;;
  stop)
    launchctl bootout system/com.kanata 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 {start|stop}" >&2
    exit 2
    ;;
esac
HELPER
      chmod 755 /usr/local/libexec/kanata-manage

      # Narrow NOPASSWD: only %admin may run the helper (no password prompt,
      # required for the non-interactive tray context). Limits are enforced
      # inside the helper itself.
      echo "%admin ALL=(root) NOPASSWD: /usr/local/libexec/kanata-manage" > /private/etc/sudoers.d/kanata-manage
      visudo -cf /private/etc/sudoers.d/kanata-manage >/dev/null
      chmod 440 /private/etc/sudoers.d/kanata-manage

      # Clean up leftover from the previous (hacked) setup:
      # NOPASSWD sudoers entry for the homebrew kanata-tray wrapper.
      rm -f /private/etc/sudoers.d/kanata-tray

      # Restart the tray so it picks up the updated kanata-tray.toml (the plist
      # itself may be unchanged, so nix-darwin will not restart the agent).
      sudo --user=${user} -- launchctl kickstart -k "gui/$(id -u ${user})/com.kanata-tray" 2>/dev/null || true
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
    #      socket above. Uses stable copy at /usr/local/bin/kanata (see TCC note).
    #   3. kanata-tray user agent (user context): GUI menubar app. It cannot
    #      spawn kanata itself (vHID socket is root-only), so it runs the
    #      lifecycle shim instead, which delegates to the root daemon and
    #      mirrors its liveness (see activation script for rationale).
    #
    # MACOS PERMISSIONS (TCC) — the critical part:
    #   macOS TCC pins the Input Monitoring / Accessibility grants to the
    #   executable's REAL path. Symlinks are resolved (tccd attributes the
    #   check to the /nix/store path), and a root daemon can never receive a
    #   TCC prompt (notifyUserOfDeniedAccessBy fails for UID 0). Therefore the
    #   kanata binary is COPIED (not symlinked) to the stable path
    #   /usr/local/bin/kanata by the activation script.
    #   ==> Grant permissions ONCE to /usr/local/bin/kanata:
    #       System Settings > Privacy & Security > Input Monitoring  (add +)
    #       System Settings > Privacy & Security > Accessibility    (add +)
    #   The grant survives nix switches/flake updates because the path never
    #   changes. (macOS may invalidate it only after a kanata VERSION bump —
    #   macOS sometimes re-pins to the original binary; if so, remove and
    #   re-add /usr/local/bin/kanata once.)
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

      # kanata runs as a root LaunchDaemon to access the Karabiner-VirtualHIDDevice
      # IPC socket at /Library/Application Support/org.pqrs/tmp/rootonly/.
      # Running as a user agent blocks access to this root-only directory.
      kanata = {
        # Runs kanata as a root LaunchDaemon via nix-darwin.
        # This gives it access to the Karabiner Virtual HID Device IPC socket
        # at /Library/Application Support/org.pqrs/tmp/rootonly/.
        # The karabiner-dk daemon must be running and approved in System Settings.
        command = "/usr/local/bin/kanata -c '${
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

    # kanata-tray runs as a user LaunchAgent (user.agents → gui domain):
    # to pause/resume kanata over TCP 5829. Declared here so it starts at
    # every login and survives nix switches (previously nothing started it).
    # Uses the stable /opt/homebrew/bin/kanata-tray path (no TCC involved).
    user.agents.kanata-tray = {
      command = "/opt/homebrew/bin/kanata-tray";
      serviceConfig = {
        Label = "com.kanata-tray";
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/kanata-tray.out.log";
        StandardErrorPath = "/tmp/kanata-tray.err.log";
      };
    };
  };

}
