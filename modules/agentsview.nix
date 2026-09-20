# AgentsView module
#
# AgentsView (https://github.com/kenn-io/agentsview, https://agentsview.io) is a
# local web viewer/dashboard for AI coding agent sessions (Claude Code, Codex,
# Pi, OpenCode, Cursor, ...). Upstream offers several setup approaches (install
# script, homebrew cask, Tauri desktop app, Docker image). This module instead
# installs the prebuilt release binary through Nix and manages the
# configuration file (~/.agentsview/config.toml) declaratively.
#
# Configuration reference: https://agentsview.io/configuration/
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.agentsview;

  # The upstream release assets follow the Go GOOS_GOARCH naming scheme.
  releaseSystem =
    let
      p = pkgs.stdenv.hostPlatform;
    in
    if p.isDarwin && p.isAarch64 then "darwin_arm64"
    else if p.isDarwin then "darwin_amd64"
    else if p.isAarch64 then "linux_arm64"
    else "linux_amd64";

  # Release hashes per version (from the upstream SHA256SUMS asset).
  # When bumping `version`, add the hashes for the new release here or provide
  # an explicit package via programs.agentsview.package.
  releaseHashes = {
    "0.43.0" = {
      darwin_arm64 = "sha256-nJw+4LrQT4hLB4FvI6fFiSO6W9WpoQV/oEgZilOko3w=";
      darwin_amd64 = "sha256-K8A9jSXcNewitUHxcu1kSAoVG587/mSwt1Tkkq/FdVM=";
      linux_amd64 = "sha256-RSDGaYdy0ttyICEqv1jX1YwJZtdDXwpasTQ3H4dN9tk=";
      linux_arm64 = "sha256-PEFBvBNWBYJGM26otJoshG8wUOmhmaqPcyyIFcLdTlA=";
    };
  };

  # The release tarball contains a single prebuilt binary (CGO/SQLite+FTS5
  # embedded), so no source build or code signing fixup is needed on macOS.
  defaultPackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "agentsview";
    version = cfg.version;

    src = pkgs.fetchurl {
      url = "https://github.com/kenn-io/agentsview/releases/download/v${cfg.version}/agentsview_${cfg.version}_${releaseSystem}.tar.gz";
      hash =
        let
          hashes = releaseHashes.${cfg.version} or (throw ''
            No pinned release hash for agentsview ${cfg.version}.
            Either update `releaseHashes` in modules/agentsview.nix or set
            programs.agentsview.package to a package of your own.
          '');
        in
        hashes.${releaseSystem} or (throw ''
          No agentsview release asset for ${releaseSystem} (version ${cfg.version}).
          Set programs.agentsview.package explicitly for this platform.
        '');
    };

    # The tarball contains a single bare binary, no directory.
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -Dm755 agentsview $out/bin/agentsview
      runHook postInstall
    '';

    meta = {
      description = "Local web viewer for AI agent sessions";
      homepage = "https://agentsview.io";
      license = lib.licenses.mit;
      mainProgram = "agentsview";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

  # Filter unset (null) values so only explicitly configured keys end up in
  # the TOML file. Only top-level nulls are filtered; avoid nesting nulls.
  filterNulls = lib.filterAttrs (_: v: v != null);

  # Union of agent ids that have dirs or homes configured.
  agentIds =
    lib.unique (
      (lib.attrNames cfg.agentDirs) ++ (lib.attrNames cfg.agentHomes)
    );

  # Typed convenience options rendered into the freeform settings attrset.
  # Arbitrary keys (e.g. `pg`, `duckdb`, `vector`, `custom_model_pricing`,
  # `session_sources` machine labels) can be set directly via
  # programs.agentsview.settings.
  settingsFromTypedOptions = lib.mkMerge [
    (lib.mkIf (cfg.host != null) { host = cfg.host; })
    (lib.mkIf cfg.requireAuth { require_auth = true; })
    (lib.mkIf (cfg.authToken != null) { auth_token = cfg.authToken; })
    (lib.mkIf (cfg.publicUrl != null) { public_url = cfg.publicUrl; })
    (lib.mkIf (cfg.publicOrigins != [ ]) { public_origins = cfg.publicOrigins; })
    (lib.mkIf (cfg.daemonIdleTimeout != null) { daemon_idle_timeout = cfg.daemonIdleTimeout; })
    (lib.mkIf (cfg.archiveContent != null) { archive_content = cfg.archiveContent; })
    (lib.mkIf (cfg.disabledAgents != [ ]) { disabled_agents = cfg.disabledAgents; })
    (lib.mkIf (cfg.agentDirs != { } || cfg.agentHomes != { }) {
      agents = lib.listToAttrs (
        map (id: {
          name = id;
          value = filterNulls {
            dirs = cfg.agentDirs.${id} or null;
            homes = cfg.agentHomes.${id} or null;
          };
        }) agentIds
      );
    })
    (lib.mkIf (cfg.sessionSources != [ ]) {
      session_sources = map filterNulls cfg.sessionSources;
    })
    (lib.mkIf (cfg.remoteHosts != [ ]) {
      remote_hosts = map filterNulls cfg.remoteHosts;
    })
    (lib.mkIf (cfg.automated != { }) { automated = cfg.automated; })
  ];

  settingsRendered = filterNulls cfg.settings;
in
{
  options.programs.agentsview = {
    enable = lib.mkEnableOption "AgentsView, the local web viewer for AI agent sessions";

    # The version-controlled config.toml installed verbatim. Synced back from
    # the live file via `make sync-config-agentsview` (ADR-0003). Set to null
    # to fall back to generating the file from settings instead.
    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = ../config/agentsview/config.toml;
      defaultText = lib.literalMD "`config/agentsview/config.toml` (version-controlled)";
      description = ''
        Config file installed verbatim to ~/.agentsview/config.toml.
        While the file does not exist yet (before the first
        `make sync-config-agentsview`), it is left to the daemon to create.
      '';
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "0.43.0";
      description = "Pinned AgentsView release version (needs matching entry in releaseHashes).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "prebuilt release binary of agentsview";
      description = "The agentsview package to install.";
    };

    # The configuration file at ~/.agentsview/config.toml is auto-generated.
    # NOTE the daemon also writes this file (Settings UI, generated secrets
    # like cursor_secret / auth_token). A rebuild switches the file back to
    # the generated version and any daemon-managed keys are regenerated.
    # Provide secrets explicitly (settings.auth_token, etc.) when they must
    # stay stable; AGENTSVIEW_AUTH_TOKEN also works as an env var override.
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Freeform settings written verbatim to ~/.agentsview/config.toml
        (https://agentsview.io/configuration/). Used for tables like
        `[pg]`, `[duckdb]`, `[vector]` and `[custom_model_pricing]`.
      '';
    };

    host = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Interface the server binds to (default `127.0.0.1`).";
    };

    requireAuth = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Require bearer-token authentication for API access.";
    };

    authToken = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Static bearer token used with require_auth. Set to a secret string or
        leave null to let agentsview auto-generate one (not persisted here).
      '';
    };

    publicUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Browser URL, trusted origin and managed Caddy site address.";
    };

    publicOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional trusted origins for request Host/Origin checks.";
    };

    daemonIdleTimeout = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Idle timeout for detached writable daemons (e.g. `20m`, `0s` to disable).";
    };

    archiveContent = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "full"
        "transcripts"
        "usage"
      ]);
      default = null;
      description = "How much of each session the archive stores (requires daemon restart).";
    };

    disableUpdateCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable the automatic update check against the GitHub API.";
    };

    telemetry.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the anonymous daemon_active telemetry ping (PostHog).
        Disabled by default via AGENTSVIEW_TELEMETRY_ENABLED=0.
      '';
    };

    disabledAgents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "gemini" ];
      description = "Session provider ids to exclude from local filesystem scanning.";
    };

    # Per-agent discovery overrides. Keys are provider ids (claude, codex,
    # pi, opencode, gemini, ...). An empty list clears the provider's
    # default directories.
    agentDirs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = {
        aider = [ "~/code" ];
        claude = [ "~/.claude/projects" ];
      };
      description = "Per-agent session directories rendered as [agents.<id>] dirs.";
    };

    agentHomes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Per-agent alternate home directories rendered as [agents.<id>] homes
        (claude, codex and pi support this).
      '';
    };

    sessionSources = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          agent = lib.mkOption { type = lib.types.str; };
          dir = lib.mkOption { type = lib.types.str; };
          machine = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Peer installation ID for roots produced on another machine.";
          };
        };
      });
      default = [ ];
      description = "Additional filesystem session roots rendered as [[session_sources]].";
    };

    remoteHosts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          host = lib.mkOption {
            type = lib.types.str;
            description = "Unique and stable host key (namespaces imported sessions).";
          };
          transport = lib.mkOption {
            type = lib.types.enum [
              "ssh"
              "http"
            ];
            default = "ssh";
          };
          user = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          port = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "HTTP transport only: URL of the remote daemon.";
          };
          token = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "HTTP transport only: bearer token of the remote daemon.";
          };
          interval = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "HTTP transport only: sync schedule (e.g. `5m`).";
          };
        };
      });
      default = [ ];
      description = "Remote machines synced by a bare `agentsview sync` ([[remote_hosts]]).";
    };

    # Custom automated-session patterns; keys: prefixes, substrings,
    # exact_matches (case-sensitive, matched against the first user message).
    automated = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = {
        prefixes = [ "INTERNAL-AUTOMATION:" ];
        substrings = [ "This is an automated repository maintenance run." ];
        exact_matches = [ "Nightly automation completed." ];
      };
      description = "Custom patterns for detecting automated sessions ([automated]).";
    };

    launchd.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Start a managed LaunchAgent running `agentsview serve` (macOS only).
        A supervised daemon does not idle-exit and is kept alive by launchd.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.agentsview.settings = settingsFromTypedOptions;

    assertions = [
      {
        assertion =
          cfg.host == null
          || cfg.host == "127.0.0.1"
          || cfg.host == "::1"
          || cfg.host == "localhost"
          || cfg.requireAuth;
        message = "agentsview: a non-loopback `host` requires requireAuth = true.";
      }
      {
        assertion = !cfg.launchd.enable || pkgs.stdenv.hostPlatform.isDarwin;
        message = "agentsview: launchd management is only available on macOS.";
      }
    ];

    home.packages = [ cfg.package ];

    # Install the version-controlled config.toml verbatim when it exists
    # (single source of truth per ADR-0003). Falls back to the generated
    # file only if `configFile` was explicitly set to null and settings are
    # present. While the VCS file does not exist yet, the daemon's
    # auto-created file is left untouched so first-run secrets survive.
    warnings = lib.optionals (
      cfg.configFile != null && ! builtins.pathExists cfg.configFile
    ) [
      "agentsview: ${toString cfg.configFile} does not exist yet — run `make sync-config-agentsview` to bootstrap it; ~/.agentsview/config.toml stays daemon-managed until then"
    ];

    home.file.".agentsview/config.toml" =
      if cfg.configFile != null then
        lib.mkIf (builtins.pathExists cfg.configFile) { source = cfg.configFile; }
      else
        lib.mkIf (settingsRendered != { }) {
          source = (pkgs.formats.toml { }).generate "agentsview-config.toml" settingsRendered;
        };

    home.sessionVariables = lib.mkMerge [
      (lib.mkIf (!cfg.telemetry.enable) { AGENTSVIEW_TELEMETRY_ENABLED = "0"; })
      (lib.mkIf cfg.disableUpdateCheck { AGENTSVIEW_DISABLE_UPDATE_CHECK = "1"; })
    ];

    # Optional persistent service via a LaunchAgent. The daemon keeps running
    # (supervised daemons ignore the idle timeout) and is restarted on failure.
    launchd.agents.agentsview = lib.mkIf cfg.launchd.enable {
      enable = true;
      config = {
        ProgramArguments = [ "${lib.getExe cfg.package}" "serve" ];
        ServiceDescription = "AgentsView session viewer";
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        StandardOutPath = "${config.home.homeDirectory}/.agentsview/serve.log";
        StandardErrorPath = "${config.home.homeDirectory}/.agentsview/serve.log";
      };
    };
  };
}
