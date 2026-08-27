{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.programs.oh-my-opencode-slim;

  # Default model configurations for each agent type
  defaultModels = {
    orchestrator = "opencode/nemotron-3-ultra-free";
    oracle = "opencode/nemotron-3-ultra-free";
    librarian = "opencode/nemotron-3-ultra-free";
    metis = "opencode/nemotron-3-ultra-free";
    momus = "opencode/nemotron-3-ultra-free";
    fixer = "opencode/nemotron-3-ultra-free";
    explorer = "opencode/nemotron-3-ultra-free";
    developer = "opencode/nemotron-3-ultra-free";
    coder = "opencode/nemotron-3-ultra-free";
    researcher = "opencode/nemotron-3-ultra-free";
  };

  # Generate the oh-my-opencode-slim.json configuration
  generateConfig = _: {
    models = cfg.models or defaultModels;
    skills = cfg.skills or [ "*" ];
    mcpPermissions = cfg.mcpPermissions or {
      orchestrator = [ "context7" "gh_grep" ];
      oracle = [ "context7" "gh_grep" ];
      librarian = [ "context7" "gh_grep" ];
      fixer = [ "context7" ];
      explorer = [ "context7" "gh_grep" ];
    };
    companion = cfg.companion or false;
    theme = cfg.theme or "dark";
    logLevel = cfg.logLevel or "info";
  };

in
{
  options.programs.oh-my-opencode-slim = {
    enable = lib.mkEnableOption "oh-my-opencode-slim agent orchestration plugin";

    models = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = defaultModels;
      description = "Model assignments for each agent type";
    };

    skills = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "*" ];
      description = "Skills to enable for agents";
    };

    mcpPermissions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {
        orchestrator = [ "context7" "gh_grep" ];
        oracle = [ "context7" "gh_grep" ];
        librarian = [ "context7" "gh_grep" ];
        fixer = [ "context7" ];
        explorer = [ "context7" "gh_grep" ];
      };
      description = "MCP server permissions per agent";
    };

    companion = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the companion desktop status window";
    };

    theme = lib.mkOption {
      type = lib.types.enum [ "light" "dark" "system" ];
      default = "dark";
      description = "UI theme";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "debug" "info" "warn" "error" ];
      default = "info";
      description = "Log level for the plugin";
    };

    # Provider configuration
    providers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = {
        kimi = { enabled = "no"; };
        openai = { enabled = "no"; };
      };
      description = "Provider configurations (kimi, openai, etc.)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure bun is available for the installer
    home.packages = [
      pkgs.bun
      pkgs.nodejs
    ];

    # Generate oh-my-opencode-slim.json configuration
    xdg.configFile."oh-my-opencode-slim.json".text = builtins.toJSON (generateConfig { });

    # Also create a project-local config for development
    xdg.configFile.".opencode/oh-my-opencode-slim.json".text = builtins.toJSON (generateConfig { });

    # Create a helper script to run the installer
    xdg.configFile."oh-my-opencode-slim/install.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # oh-my-opencode-slim installer helper
        # Run this after applying the Nix configuration to install/configure the plugin

        set -euo pipefail

        echo "Installing oh-my-opencode-slim..."
        bunx oh-my-opencode-slim@latest install \
          --no-tui \
          --kimi=${cfg.providers.kimi.enabled or "no"} \
          --openai=${cfg.providers.openai.enabled or "no"} \
          --tmux=no \
          ${if cfg.companion then "--companion=yes" else "--companion=no"}

        echo ""
        echo "Installation complete. Now authenticate with your providers:"
        echo "  opencode auth login"
        echo ""
        echo "Then refresh models:"
        echo "  opencode models --refresh"
        echo ""
        echo "Configuration file: ~/.config/opencode/oh-my-opencode-slim.json"
      '';
    };

    # Create a systemd/user service to run installer on first login (optional)
    # This is commented out since it requires user interaction
    # systemd.user.services."oh-my-opencode-slim-install" = {
    #   description = "Install oh-my-opencode-slim plugin";
    #   wantedBy = [ "graphical-session.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = "${config.xdg.configHome}/oh-my-opencode-slim/install.sh";
    #     RemainAfterExit = true;
    #   };
    # };
  };
}