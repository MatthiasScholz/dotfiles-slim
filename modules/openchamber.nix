# OpenChamber module
#
# OpenChamber (https://github.com/openchamber/openchamber) is an agentic
# development environment built on top of the OpenCode AI agent. Upstream ships
# desktop apps, a VS Code extension and a CLI/Web server. Only the CLI/Web
# surface is installable through Nix here, via the published `@openchamber/web`
# npm package (see packages/openchamber/default.nix).
#
# OpenChamber drives an OpenCode server: by default it starts and supervises its
# own, but it can also attach to one you already run by setting
# `environment.OPENCODE_HOST = "http://localhost:4096"` and
# `environment.OPENCODE_SKIP_START = "true"` (see
# https://docs.openchamber.dev/opencode-server/).
#
# `launchd.enable` replaces `openchamber startup enable`: upstream writes a
# LaunchAgent and snapshots the current shell environment into it, which is not
# reproducible. Here the service is declared in Nix instead — see
# `environment` for the variables that snapshot would have captured.
#
# `configFile` installs a version-controlled `preferences.json` — the profile
# keys OpenChamber writes when a setting changes in the UI. Those UI changes
# are lost on the next switch unless they are copied back first, which is what
# `make sync-config-openchamber` does (same git-review flow as ADR-0003).
#
# `desktopClient` configures the *separately installed* desktop app (Homebrew
# cask `openchamber`, see darwin/darwin.nix) to attach to this server instead of
# starting its own embedded one. It exports OPENCHAMBER_SKIP_LOCAL_SERVER and
# OPENCHAMBER_SERVER_URL as session variables, which the desktop app picks up
# through its login-shell probe. The app itself is not installed here — see
# docs/adr/0008-openchamber-desktop-client.md.
#
# `opencodePasswordFile` supplies OPENCODE_SERVER_PASSWORD to the LaunchAgent so
# it can authenticate to an external OpenCode v2 server in OPENCODE_SKIP_START
# mode — see docs/adr/0009-opencode-v2-from-npm.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.openchamber;

  # Prebuilt npm package, see packages/openchamber/default.nix.
  defaultPackage = pkgs.callPackage ../packages/openchamber { };

  # Point OpenChamber at the Nix-managed opencode. This matters for the
  # LaunchAgent, whose PATH is not the login shell's, and keeps the CLI and the
  # service on the same binary.
  # NOTE the CLI reads OPENCODE_BINARY first; OPENCHAMBER_OPENCODE_BIN is the
  # server-side fallback and OPENCODE_PATH is accepted as well.
  opencodeBinary = lib.optionalAttrs (config.programs.opencode.enable or false) {
    OPENCODE_BINARY = lib.getExe config.programs.opencode.package;
  };

  isLoopbackHost =
    host:
    builtins.elem host [
      "127.0.0.1"
      "localhost"
      "::1"
    ];

  # A password can come from the environment or from a decrypted secret file
  # (agenix, ...). Both satisfy OpenChamber's own LAN exposure check.
  uiPasswordConfigured =
    cfg.uiPasswordFile != null || (cfg.environment.OPENCHAMBER_UI_PASSWORD or "") != "";

  allowUnauthenticatedLan = (cfg.environment.OPENCHAMBER_ALLOW_UNAUTHENTICATED_LAN or "") == "true";

  serveArgs = [
    "serve"
    "--foreground"
    "--host"
    cfg.host
    "--port"
    (toString cfg.port)
  ]
  ++ lib.optionals cfg.apiOnly [ "--api-only" ]
  ++ cfg.extraArgs;

  # launchd cannot expand files into `EnvironmentVariables`, so when secrets
  # live in files we wrap the binary and read them at service start. Only the
  # file paths end up in the Nix store, never the secrets themselves.
  #
  # - `uiPasswordFile` sets OPENCHAMBER_UI_PASSWORD (the browser login).
  # - `opencodePasswordFile` is a shell `export OPENCODE_SERVER_PASSWORD=...`
  #   line, sourced so OpenChamber can authenticate to an external OpenCode v2
  #   server in OPENCODE_SKIP_START mode.
  #
  # agenix decrypts secrets from its own LaunchAgent at login, so the files can
  # briefly be missing/dangling; wait (bounded) before starting.
  launchdExec =
    if cfg.uiPasswordFile == null && cfg.opencodePasswordFile == null then
      lib.getExe cfg.package
    else
      toString (
        pkgs.writeShellScript "openchamber-launchd" ''
          ${lib.optionalString (cfg.uiPasswordFile != null) ''
            secret="${toString cfg.uiPasswordFile}"
            i=0
            while [ ! -r "$secret" ] && [ "$i" -lt 60 ]; do
              sleep 1
              i=$((i + 1))
            done
            if [ -r "$secret" ]; then
              OPENCHAMBER_UI_PASSWORD="$(cat "$secret")"
              export OPENCHAMBER_UI_PASSWORD
            else
              echo "openchamber-launchd: $secret not readable after 60s; starting without UI password" >&2
            fi
          ''}
          ${lib.optionalString (cfg.opencodePasswordFile != null) ''
            opencode_secret="${toString cfg.opencodePasswordFile}"
            i=0
            while [ ! -r "$opencode_secret" ] && [ "$i" -lt 60 ]; do
              sleep 1
              i=$((i + 1))
            done
            if [ -r "$opencode_secret" ]; then
              # shellcheck disable=SC1090
              . "$opencode_secret"
            else
              echo "openchamber-launchd: $opencode_secret not readable after 60s; external OpenCode auth will fail" >&2
            fi
          ''}
          exec ${lib.getExe cfg.package} "$@"
        ''
      );

  # launchd starts jobs with a minimal environment, unlike a login shell.
  # Include the Home Manager profile and Homebrew so tools OpenChamber shells
  # out to (git, ssh, gh, ...) keep working.
  launchdPath = lib.concatStringsSep ":" [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];

  # Same location upstream uses for its self-installed LaunchAgent.
  logDir = "${config.home.homeDirectory}/Library/Logs/OpenChamber";

  sessionEnvironment = {
    OPENCHAMBER_PORT = toString cfg.port;
  }
  // lib.optionalAttrs (cfg.dataDir != null) { OPENCHAMBER_DATA_DIR = toString cfg.dataDir; }
  // opencodeBinary
  // cfg.environment;

  # URL the separately installed desktop app attaches to (ADR-0008). The server
  # binds `host` (often a wildcard such as 0.0.0.0), but a client on the same
  # machine reaches it over loopback, so the wildcard/any addresses are mapped.
  desktopServerUrl =
    if cfg.desktopClient.serverUrl != null then
      cfg.desktopClient.serverUrl
    else
      "http://${
        if cfg.host == "0.0.0.0" then
          "127.0.0.1"
        else if cfg.host == "::1" then
          "[::1]"
        else
          cfg.host
      }:${toString cfg.port}";

  # `OPENCHAMBER_HOST` is deliberately service-only: exporting a non-loopback
  # host to the interactive shell would make a bare `openchamber` refuse to
  # start, since the UI password lives in a file only the LaunchAgent reads.
  # The CLI reaches the LAN-bound service over loopback (0.0.0.0 includes it).
  launchdEnvironment = {
    HOME = config.home.homeDirectory;
    PATH = launchdPath;
    OPENCHAMBER_HOST = cfg.host;
  }
  // lib.optionalAttrs cfg.apiOnly { OPENCHAMBER_API_ONLY = "true"; }
  // sessionEnvironment;
in
{
  options.programs.openchamber = {
    enable = lib.mkEnableOption "OpenChamber, the OpenCode-based agentic development environment";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "prebuilt @openchamber/web npm package (packages/openchamber)";
      description = "The openchamber package to install.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Web server port (OpenChamber default).";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address the web server binds to. A non-loopback address requires a UI
        password (see `uiPasswordFile` or `environment`), otherwise OpenChamber
        refuses to start.
      '';
    };

    apiOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Headless mode: serve API routes only, without the browser UI assets.
        Intended for desktop/mobile clients that connect over the API
        (`openchamber startup enable --api-only` upstream).
      '';
    };

    uiPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "config.age.secrets.openchamber.path";
      description = ''
        File containing the UI password. The LaunchAgent reads it when the
        service starts, so only the file path — never the secret — is written to
        disk by Nix. Use an absolute path outside the repo (an agenix secret
        path, for instance); a path inside this repo would be copied into the
        world-readable Nix store. Only affects the LaunchAgent; the interactive
        CLI still needs `OPENCHAMBER_UI_PASSWORD` or `--ui-password`.
      '';
    };

    opencodePasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "config.age.secrets.opencode-server.path";
      description = ''
        File with an `export OPENCODE_SERVER_PASSWORD=...` line for the external
        OpenCode v2 server this module attaches to via `OPENCODE_HOST`. The
        LaunchAgent wrapper sources it, so only the file path reaches the store
        — never the secret. Only meaningful in `OPENCODE_SKIP_START` mode; when
        OpenChamber manages OpenCode it generates and keeps its own password.
        See docs/adr/0009-opencode-v2-from-npm.md.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/Users/matthias/.local/share/openchamber";
      description = ''
        Directory for OpenChamber state (settings, logs, tunnel profiles).
        Defaults to `~/.config/openchamber` when null.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = ../config/openchamber/preferences.json;
      defaultText = lib.literalMD "`config/openchamber/preferences.json` (version-controlled)";
      description = ''
        Version-controlled copy of the user's profile settings, installed to
        `~/.config/openchamber/preferences.json` (the file OpenChamber writes
        when a setting changes in the UI). A rebuild would otherwise overwrite
        those changes, so run `make sync-config-openchamber` first to review
        them and merge what should stay. Set to null to leave the file entirely
        daemon-managed.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--ui-password"
        "be-creative-here"
      ];
      description = "Extra arguments appended to the `openchamber serve` invocation.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        OPENCODE_HOST = "http://localhost:4096";
        OPENCODE_SKIP_START = "true";
      };
      description = ''
        Environment variables for the session and the LaunchAgent. This is the
        declarative replacement for the environment snapshot `openchamber
        startup enable` would have taken.
        NOTE values are written to the Nix store/world-readable files; use
        `uiPasswordFile` for secrets.
      '';
    };

    desktopClient = {
      enable = lib.mkEnableOption ''
        Client mode for the separately installed OpenChamber desktop app. When
        enabled, this server keeps its port and data directory and the desktop
        app attaches here (loading its bundled UI and talking to this server's
        API) instead of starting its own embedded server. See
        docs/adr/0008-openchamber-desktop-client.md.
      '';

      serverUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        defaultText = lib.literalExpression "http://<host>:<port> derived from `host`/`port`";
        example = "http://127.0.0.1:3000";
        description = ''
          URL the desktop app connects to. Defaults to this server's own
          address (`127.0.0.1` when bound to `0.0.0.0`, otherwise `host`).
        '';
      };
    };

    launchd.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run OpenChamber as a managed LaunchAgent (macOS only), started at login
        and kept alive by launchd. The declarative equivalent of
        `openchamber startup enable`.
        NOTE if you ever ran `openchamber startup enable` before, run
        `openchamber startup disable` once so its `dev.openchamber.web` agent
        does not fight this one over the port.
        NOTE a manually started daemon (`openchamber` without `--foreground`)
        binds the same port. While it runs, this agent exits 1 and launchd
        restarts it in a loop (`Error: OpenChamber is already running on port
        ...` in ~/Library/Logs/OpenChamber/startup.err.log). Stop the stray
        instance with `openchamber stop --port <port>`; launchd then starts the
        service within its throttle interval.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.launchd.enable || pkgs.stdenv.hostPlatform.isDarwin;
        message = "openchamber: launchd management is only available on macOS.";
      }
      {
        assertion = isLoopbackHost cfg.host || uiPasswordConfigured || allowUnauthenticatedLan;
        message = ''
          openchamber: host "${cfg.host}" is network-exposed but no UI password is
          configured. Set programs.openchamber.uiPasswordFile (or
          environment.OPENCHAMBER_UI_PASSWORD), or bind to 127.0.0.1.
        '';
      }
      {
        assertion = cfg.configFile == null || cfg.dataDir == null;
        message = ''
          openchamber: configFile management assumes the default data dir
          (~/.config/openchamber). Set dataDir = null, or configFile = null to
          leave the file daemon-managed.
        '';
      }
    ];

    home.packages = [ cfg.package ];

    # OpenChamber writes preferences.json itself at runtime (tmp + rename, so
    # it replaces whatever symlink Home Manager installed). Copy those changes
    # back before they are clobbered: `make sync-config-openchamber`.
    warnings = lib.optionals (cfg.configFile != null && !builtins.pathExists cfg.configFile) [
      "openchamber: ${toString cfg.configFile} does not exist yet — run `make sync-config-openchamber` to bootstrap it; ~/.config/openchamber/preferences.json stays daemon-managed until then"
    ];

    home.file.".config/openchamber/preferences.json" =
      lib.mkIf (cfg.configFile != null && builtins.pathExists cfg.configFile)
        {
          source = cfg.configFile;
        };

    # Desktop-client variables are session-only. They are read exclusively by
    # the Electron desktop app (never by the CLI/server), so they must not leak
    # into the LaunchAgent environment or anything the server spawns.
    home.sessionVariables = sessionEnvironment // lib.optionalAttrs cfg.desktopClient.enable {
      OPENCHAMBER_SKIP_LOCAL_SERVER = "1";
      OPENCHAMBER_SERVER_URL = desktopServerUrl;
    };

    # launchd opens the log files before the process starts, so make sure the
    # directory exists even on a machine that has never run OpenChamber.
    home.activation.openchamberLogDir = lib.mkIf cfg.launchd.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "${logDir}"
      ''
    );

    launchd.agents.openchamber = lib.mkIf cfg.launchd.enable {
      enable = true;
      config = {
        ProgramArguments = [ launchdExec ] ++ serveArgs;
        ServiceDescription = "OpenChamber agentic development environment";
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        WorkingDirectory = config.home.homeDirectory;
        EnvironmentVariables = launchdEnvironment;
        StandardOutPath = "${logDir}/startup.log";
        StandardErrorPath = "${logDir}/startup.err.log";
      };
    };
  };
}
