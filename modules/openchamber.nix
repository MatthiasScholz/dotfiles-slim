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

  # launchd cannot expand files into `EnvironmentVariables`, so when the UI
  # password lives in a file we wrap the binary and read it at service start.
  # Only the file path ends up in the Nix store, never the secret itself.
  #
  # agenix decrypts secrets from its own LaunchAgent at login, so the file can
  # briefly be missing/dangling; wait (bounded) before starting — a
  # network-exposed server without its password refuses to start anyway.
  launchdExec =
    if cfg.uiPasswordFile == null then
      lib.getExe cfg.package
    else
      toString (
        pkgs.writeShellScript "openchamber-launchd" ''
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

    home.sessionVariables = sessionEnvironment;

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
