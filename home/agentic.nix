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

    # Dynamically select the package based on architecture
    # package =
    # if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then
    #   inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
    #   else
    #     let
    #       appVersion = "1.1.48";
    #     in
    #     # The fallback derivation for your Intel Mac Pro
    #     pkgs.stdenv.mkDerivation {
    #       pname = "opencode-baseline";
    #       # FIXME broken baseline version = "1.14.33";
    #       version = appVersion;

    #       src = pkgs.fetchzip {
    #         # FIXME broken baseline version
    #         # url =
    #         #  "https://github.com/anomalyco/opencode/releases/download/"
    #         #  + "v${version}/opencode-darwin-x64-baseline.zip";
    #         # hash = "sha256-Ux4jwHAWC2A3UDGIiu3cofjAqOAzUOLZl6zWYj6L5SY=";
    #         url =
    #           "https://github.com/anomalyco/opencode/releases/download/"
    #           + "v${appVersion}/opencode-darwin-x64.zip";
    #         # hash = pkgs.lib.fakeHash;
    #         hash = "sha256-WQERmuHfs4s8mmYCW7te8sWHEh9u8R0WkVvaErr2ZQA";
    #       };

    #       installPhase = ''
    #         mkdir -p $out/bin
    #         # Copy the extracted binary into the Nix store bin directory
    #         cp opencode $out/bin/opencode
    #         chmod +x $out/bin/opencode
    #       '';

    #       meta = {
    #         mainProgram = "opencode";
    #         description = "OpenCode AI agent";
    #       };
    #     };

    web = {
      enable = true;
      extraArgs = [
        "--hostname"
        "0.0.0.0"
        "--port"
        "4096"
        "--mdns"
      ];
    };

    enableMcpIntegration = true;

    settings = {
      autoupdate = false;
      plugin = [
        # Pinned versions (updated via make update -> scripts/update-opencode-plugin-versions.sh)
        "@mohak34/opencode-notifier@${pluginVersions."@mohak34/opencode-notifier"}"
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
    #../modules/oh-my-openagent.nix
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

  /*
    # oh-my-openagent orchestration plugin in the dedicated "omo" profile
    programs.ohMyOpenagent = {
      enable = true;
      profile = "omo"; # Profile name (omo, personal, work, etc.)
      # plugins default to pinned "[oh-my-openagent@<version>]" from the versions file

      # Agent model configuration (mirrors oh-my-openagent.jsonc)
      agents = {
        # Sisyphus (Main Orchestrator): Requires heavy reasoning and autonomous execution.
        sisyphus = {
          model = "opencode/nemotron-3-ultra";
          variant = "max";
          fallback_models = [
            "opencode/laguna-s-2.1"
            "opencode/big-pickle"
          ];
        };
        # Oracle (Architecture Consultant): Needs high-IQ architecture decisions.
        oracle = {
          model = "opencode/nemotron-3-ultra";
          variant = "high";
          fallback_models = [ "opencode/laguna-s-2.1" ];
        };
        # Librarian (Documentation Search): Needs long context and speed.
        librarian = {
          model = "opencode/ling-3.0-flash";
          fallback_models = [
            "opencode/deepseek-v4-flash"
            "opencode/north-mini-code"
          ];
        };
        # Explore (Fast Codebase Grep): Optimized for rapid pattern discovery.
        explore = {
          model = "opencode/deepseek-v4-flash";
          fallback_models = [
            "opencode/north-mini-code"
            "opencode/ling-3.0-flash"
          ];
        };
        # Multimodal Looker (Vision): Requires screenshot and UI analysis.
        "multimodal-looker" = {
          model = "opencode/mimo-v2.5";
          fallback_models = [ "opencode/nemotron-3-ultra" ];
        };
        # Prometheus (Strategic Planner): Inherits heavy reasoning from Sisyphus.
        prometheus = {
          model = "opencode/nemotron-3-ultra";
          variant = "max";
          fallback_models = [ "opencode/laguna-s-2.1" ];
        };
        # Metis (Gap Analyzer): Needs strict instruction-following to catch blind spots.
        metis = {
          model = "opencode/laguna-s-2.1";
          variant = "max";
          fallback_models = [ "opencode/nemotron-3-ultra" ];
        };
        # Momus (Ruthless Reviewer): Validates plans against context criteria.
        momus = {
          model = "opencode/laguna-s-2.1";
          variant = "max";
          fallback_models = [ "opencode/nemotron-3-ultra" ];
        };
        # Atlas (Execution Conductor): Distributes tasks based on plans.
        atlas = {
          model = "opencode/nemotron-3-ultra";
          fallback_models = [ "opencode/laguna-s-2.1" ];
        };
      };

      # Category model configuration
      categories = {
        # UI/Frontend Tasks
        "visual-engineering" = {
          model = "opencode/mimo-v2.5";
          variant = "high";
          fallback_models = [ "opencode/nemotron-3-ultra" ];
        };
        # Hard Logic and Architecture
        ultrabrain = {
          model = "opencode/nemotron-3-ultra";
          variant = "high";
          fallback_models = [ "opencode/laguna-s-2.1" ];
        };
        # Creative/Unconventional Tasks
        artistry = {
          model = "opencode/big-pickle";
          variant = "high";
          fallback_models = [ "opencode/nemotron-3-ultra" ];
        };
        # Trivial/Fast Tasks
        quick = {
          model = "opencode/north-mini-code";
          fallback_models = [
            "opencode/deepseek-v4-flash"
            "opencode/ling-3.0-flash"
          ];
        };
        # Light Fallback Category
        "unspecified-low" = {
          model = "opencode/deepseek-v4-flash";
          fallback_models = [ "opencode/north-mini-code" ];
        };
        # High-Effort Fallback Category
        "unspecified-high" = {
          model = "opencode/nemotron-3-ultra";
          variant = "max";
          fallback_models = [ "opencode/laguna-s-2.1" ];
        };
        # Prose and Documentation
        writing = {
          model = "opencode/ling-3.0-flash";
          fallback_models = [ "opencode/laguna-s-2.1" ];
        };
      };

      # Optional: enable companion desktop window
      companion = false;
    };
  */

  # Optional: Pre-define your favorite registries globally
  xdg.configFile."ocx/ocx.jsonc".text = builtins.toJSON {
    registries = [ "https://registry.kdco.dev" ];
    telemetry = false;
  };

  home.packages = [
    # FIXME uses postgresql test which is unsupported for darwin
    #pkgs.open-webui
    # Ggogle
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
}
