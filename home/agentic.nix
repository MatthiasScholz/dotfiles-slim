{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Import our custom derivation
  pi-acp = pkgs.callPackage ./packages/pi-acp/default.nix { };

  # Pinned OpenCode plugin versions (refreshed via `make update`)
  pluginVersions = import ../modules/opencode-plugin-versions.nix;

  # Shared LaunchAgent secret-env shim (lib/launchd.nix).
  launchdLib = import ../lib/launchd.nix { inherit lib pkgs; };
in
{
  # https://github.com/nix-community/home-manager/blob/master/modules/programs/mcp.nix
  # NOTE Reused in opencode
  programs.mcp = {
    enable = true;
    servers = {
      mermaid = {
        command = "bun";
        args = [
          "x"
          "mcp-mermaid"
        ];
      };
      devenv = {
        command = "devenv";
        args = [
          "mcp"
        ];
      };
      # TODO add somehow the homeassistant MCP, but not in general availability
    };
  };

  # https://github.com/nix-community/home-manager/blob/master/modules/programs/opencode.nix
  programs.opencode = {
    enable = true;

    # OpenCode v2. nixpkgs `pkgs.opencode` still tracks the 1.x line, whose
    # server API OpenChamber v2 rejects. packages/opencode packages the
    # published @opencode/cli v2 artifact (per-arch hashes inside). See
    # docs/adr/0009-opencode-v2-from-npm.md.
    package = pkgs.callPackage ../packages/opencode { };

    web = {
      enable = true;
      # NOTE v2 `serve` has no `--mdns` flag (v1 did); the LAN/mDNS discovery
      # moved to the background `service` subsystem.
      extraArgs = [
        "--hostname"
        "0.0.0.0"
        "--port"
        "4096"
      ];
      # OpenCode v2 requires a server password. Home Manager's darwin launchd
      # wrapper only `source`s the environment file — it does not wait for
      # agenix to decrypt it — so point it at a shared shim that waits (bounded)
      # and then sources the secret (lib/launchd.nix). NOTE darwin-only: on
      # Linux systemd would parse this as a KEY=VALUE EnvironmentFile.
      environmentFile = launchdLib.mkSecretEnvFile {
        name = "opencode-server";
        secrets = [
          {
            kind = "source";
            file = config.age.secrets."opencode-server".path;
          }
        ];
      };
    };

    enableMcpIntegration = true;

    settings = {
      autoupdate = false;
      plugin = [
        # Pinned versions (updated via make update -> scripts/update-opencode-plugin-versions.sh)
        "opencode-gemini-auth@${pluginVersions."opencode-gemini-auth"}"
        #"opencode-nanobanana@${pluginVersions."opencode-nanobanana"}"
        "opencode-mem@${pluginVersions."opencode-mem"}"
        "@ramtinj95/opencode-tokenscope@${pluginVersions."@ramtinj95/opencode-tokenscope"}"
        # NOTE OTel plugin needs additional configuration, either via opencode.jsonc or environment variables
        # TODO Add additional integration into the nix configuration
        "@devtheops/opencode-plugin-otel@${pluginVersions."@devtheops/opencode-plugin-otel"}"
        "oh-my-opencode-slim@${pluginVersions."oh-my-opencode-slim"}"
      ];
    };

  };

  # TODO inject my configuration repository with ocx
  # TODO only do when opencode is setup -> move opencode into separate nix file
  # Better opencode management
  imports = [
    ../modules/ocx-module.nix
    ../modules/oh-my-opencode-slim.nix
    ../modules/openchamber.nix
  ];

  # Enable it globally with a single flag
  programs.ocx.enable = false;

  # oh-my-opencode-slim orchestration plugin in the "personal" profile
  # Uses the OpenCode Zen Free preset (all agents on opencode free models, no cost)
  # https://github.com/alvinunreal/oh-my-opencode-slim/blob/master/docs/opencode-zen-free-preset.md
  programs.oh-my-opencode-slim = {
    enable = true;
    profile = "personal";
    # Active preset (defaults to "opencode-zen-free")
    # preset = "opencode-zen-free";
    # Optional: enable companion desktop window
    companion = false;
  };

  # Optional: Pre-define your favorite registries globally
  xdg.configFile."ocx/ocx.jsonc".text = builtins.toJSON {
    registries = [ "https://registry.kdco.dev" ];
    telemetry = false;
  };

  home.packages = [
    # FIXME uses postgresql test which is unsupported for darwin
    #pkgs.open-webui
    # Google
    pkgs.antigravity-cli
    # PI
    # https://pi.dev, https://github.com/badlogic/pi-mono/, https://lucumr.pocoo.org/2026/1/31/pi/
    pkgs.pi-coding-agent
    pi-acp
    # Claude Code
    pkgs.claude-code
    pkgs.claude-agent-acp
    # AIDER
    # BROKEN aider-chat-full
    # BROKEN aider-chat-with-help
    # WORKS aider-chat
    # WORKS aider-chat-with-browser
    # WORKS
    # UNUSED aider-chat-with-playwright
    # CRUSH
    # NOTE focused on cli and api keys, no web ui
    # .https://github.com/charmbracelet/crush
    # NOTE Does not seem to support ACP (2026-01-09)
    # FIXME broken 2026-01-26
    # crush
  ];

  # AgentsView - local web viewer for AI agent sessions
  # https://github.com/kenn-io/agentsview (installed via Nix release binary,
  # config.toml generated declaratively, no Docker/homebrew involved)
  programs.agentsview = {
    enable = true;
    launchd.enable = true;

    # Example per-agent overrides (see https://agentsview.io/configuration/):
    # agentDirs = {
    #   aider = [ "~/code" ];
    #   claude = [ "~/.claude/projects" ];
    # };
    # disabledAgents = [ "gemini" ];

    # Freeform TOML pass-through for tables like [pg], [duckdb], [vector]:
    # settings.pg.url = "postgres://user:pass@work-db/agentsview";
  };

  # OpenChamber - agentic development environment on top of OpenCode
  # https://github.com/openchamber/openchamber (CLI/Web installed from the
  # published @openchamber/web npm package; drives the programs.opencode above)
  # Runs as a launchd LaunchAgent, the declarative equivalent of upstream's
  # `openchamber startup enable`.
  #
  # Bound to 0.0.0.0 so other devices on the LAN (desktop/mobile/PWA) can reach
  # it, which OpenChamber only allows with UI auth — hence the agenix password
  # below (ADR-0004). The agenix CLI defaults to ~/.ssh/id_rsa|id_ed25519, so
  # pass the repo's age key explicitly (secrets.nix holds the recipients):
  #   read:   make openchamber-password
  #   rotate: agenix -e secrets/openchamber-web.age -i ~/.config/sops/age/keys.txt
  # The decrypted copy is also at ~/.agenix/openchamber-web after a switch.
  age.secrets."openchamber-web" = {
    file = ../secrets/openchamber-web.age;
    path = "${config.home.homeDirectory}/.agenix/openchamber-web";
  };

  # Shared OpenCode v2 server password (see ADR-0009): read by the OpenCode
  # web service and by the OpenChamber LaunchAgent (modules/openchamber.nix
  # `opencodePasswordFile`). Content is a shell `export OPENCODE_SERVER_PASSWORD=...`.
  age.secrets."opencode-server" = {
    file = ../secrets/opencode-server.age;
    path = "${config.home.homeDirectory}/.agenix/opencode-server";
  };

  programs.openchamber = {
    enable = true;
    port = 3000;
    launchd.enable = true;
    host = "0.0.0.0";
    uiPasswordFile = config.age.secrets."openchamber-web".path;

    # Authenticate to the external OpenCode v2 server (OPENCODE_SKIP_START
    # mode) with the shared server password. Read by the LaunchAgent wrapper,
    # never written to the store.
    opencodePasswordFile = config.age.secrets."opencode-server".path;

    # Attach to the OpenCode server programs.opencode already runs on :4096
    # instead of supervising a second one. Deterministic replacement for the
    # auto-detect step documented in modules/openchamber.nix.
    environment.OPENCODE_HOST = "http://localhost:4096";
    environment.OPENCODE_SKIP_START = "true";

    # Run the separately installed desktop app (Homebrew cask `openchamber`)
    # as a client of this server instead of as a second embedded server — one
    # server owns the port and ~/.config/openchamber, the desktop loads its
    # bundled UI and talks to this API. See ADR-0008.
    desktopClient.enable = true;

    # Headless API-only server (no browser UI assets):
    # apiOnly = true;
  };
}
