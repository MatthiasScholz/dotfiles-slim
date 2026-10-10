{ config, pkgs, ... }:

{
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

            # === Stable copy + stable signature of the kanata binary (TCC) ===
            # /usr/local/bin/kanata must be a REAL FILE COPY, never a symlink:
            # macOS TCC resolves symlinks and attributes the grant to the real
            # executable path. It must also be re-signed with a STABLE identity:
            # an ad-hoc binary's TCC requirement is its cdhash, which changes on
            # every rebuild (a nixpkgs bump rebuilds kanata even at the same
            # version). With a stable self-signed identity TCC stores
            # `identifier "com.kanata.kanata" and certificate leaf = H"..."`,
            # which survives rebuilds, so the copy can be refreshed every switch
            # and the grant keeps matching. The identity lives in the root-only
            # System keychain; its private key never enters the repo or the nix
            # store. See docs/adr/0006-kanata-tcc-stable-signing.md.
            #
            # The initial grant (Input Monitoring + Accessibility) is a one-time
            # manual step: root daemons cannot be shown a TCC prompt, and the
            # grant cannot be migrated programmatically (SIP keeps TCC.db
            # read-only; tccutil cannot target a path client).
            if ! /usr/bin/security find-identity -v -p codesigning /Library/Keychains/System.keychain 2>/dev/null | grep -q 'kanata-tcc'; then
              echo "INFO :: Creating stable 'kanata-tcc' code-signing identity"
              sigdir=$(mktemp -d)
              cat > "$sigdir/openssl.cnf" <<'OSSL'
      [req]
      distinguished_name = dn
      x509_extensions = v3
      prompt = no
      [dn]
      CN = kanata-tcc
      [v3]
      basicConstraints = critical,CA:false
      keyUsage = critical,digitalSignature
      extendedKeyUsage = critical,codeSigning
      OSSL
              /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -keyout "$sigdir/key.pem" -out "$sigdir/cert.pem" -days 3650 -config "$sigdir/openssl.cnf" >/dev/null 2>&1
              /usr/bin/openssl pkcs12 -export -inkey "$sigdir/key.pem" -in "$sigdir/cert.pem" -out "$sigdir/id.p12" -passout pass:kanata -name kanata-tcc >/dev/null 2>&1
              # Only /usr/bin/codesign may use the private key; no -A (all apps).
              /usr/bin/security import "$sigdir/id.p12" -k /Library/Keychains/System.keychain -P kanata -T /usr/bin/codesign >/dev/null
              # Trust scoped to the codeSigning policy only (does not affect TLS).
              /usr/bin/security add-trusted-cert -d -r trustRoot -p codeSign -k /Library/Keychains/System.keychain "$sigdir/cert.pem" >/dev/null
              rm -rf "$sigdir"
            fi

            echo "INFO :: Installing kanata binary at /usr/local/bin/kanata"
            mkdir -p /usr/local/bin /usr/local/libexec
            src="${pkgs.kanata-with-cmd}/bin/kanata"
            want=$(/usr/bin/shasum -a 256 "$src" | /usr/bin/awk '{print $1}')
            have=$(cat /usr/local/libexec/kanata.src-sha256 2>/dev/null || true)
            if [ ! -x /usr/local/bin/kanata ] || [ "$want" != "$have" ]; then
              cp -f "$src" /usr/local/bin/kanata
              chmod 755 /usr/local/bin/kanata
            fi
            # (Re-)sign unless the copy already carries the stable identity.
            if ! /usr/bin/codesign -d -r- /usr/local/bin/kanata 2>/dev/null | grep -q 'certificate leaf'; then
              /usr/bin/codesign --force -s kanata-tcc --identifier com.kanata.kanata /usr/local/bin/kanata >/dev/null
            fi
            /usr/bin/codesign -d -r- /usr/local/bin/kanata 2>/dev/null | grep -q 'certificate leaf' || {
              echo "ERROR :: /usr/local/bin/kanata is not signed with the stable kanata-tcc identity" >&2
              exit 1
            }
            printf '%s\n' "$want" > /usr/local/libexec/kanata.src-sha256
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
          # disable (persistent) so the pause survives reboots; bootout only
          # unloads the current instance and would be undone by launchd at boot.
          launchctl disable system/com.kanata 2>/dev/null || true
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
