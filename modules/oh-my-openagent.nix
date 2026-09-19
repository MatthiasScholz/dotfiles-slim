{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.programs.ohMyOpenagent;

  # Pinned plugin versions (refreshed via `make update` -> scripts/update-opencode-plugin-versions.sh)
  pluginVersions = import ./opencode-plugin-versions.nix;

  # Plugin spec with the pinned version, e.g. "oh-my-openagent@4.19.4"
  pluginSpec = "oh-my-openagent@${cfg.version}";

  # Profile name (defaults to "omo")
  profileName = cfg.profile;

  # Profile-specific config directory (opencode profile dirs are PLURAL: profiles/<name>)
  profileConfigDir = "opencode/profiles/${profileName}";

  # Agent model configuration for oh-my-openagent
  # Schema: https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/omo.schema.json
  generateConfig = _: {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/omo.schema.json";
    agents = cfg.agents;
    categories = cfg.categories;
  };

  # OpenCode profile config (opencode.jsonc in the profile dir)
  generateOpenCodeConfig = _: {
    "$schema" = "https://opencode.ai/config.json";
    plugin = cfg.plugins;
  };
in
{
  options.programs.ohMyOpenagent = {
    enable = lib.mkEnableOption "oh-my-openagent agent orchestration plugin";

    # Pinned plugin version (default from modules/opencode-plugin-versions.nix)
    version = lib.mkOption {
      type = lib.types.str;
      default = pluginVersions."oh-my-openagent";
      description = "Pinned oh-my-openagent version (refreshed by make update)";
    };

    # Plugins registered in the profile's tui.json (TUI version badge)
    tuiPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ pluginSpec ];
      description = "Plugins to register in the profile's tui.json";
    };

    profile = lib.mkOption {
      type = lib.types.str;
      default = "omo";
      description = "OpenCode profile name (e.g., 'omo', 'personal', 'work')";
    };

    # Plugin list for the profile's opencode.jsonc
    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ pluginSpec ];
      description = "Plugins to register in the profile's opencode.jsonc";
    };

    # Per-agent model configuration (mirrors oh-my-openagent.jsonc)
    agents = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Agent model configuration (sisyphus, oracle, librarian, ...)";
    };

    # Per-category model configuration (mirrors oh-my-openagent.jsonc)
    categories = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Category model configuration (visual-engineering, ultrabrain, ...)";
    };

    # OpenCode settings managed by the plugin
    companion = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the desktop companion status window";
    };

    disableDefaultAgents = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable OpenCode built-in 'explore' and 'general' agents";
    };

    enableLsp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable LSP integration by default";
    };

    backgroundSubagents = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OpenCode background subagents and Exa websearch via environment variables";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure bun and nodejs are available for the plugin runtime
    home.packages = [
      pkgs.bun
      pkgs.nodejs
    ];

    # Generate oh-my-openagent.jsonc in the profile directory
    xdg.configFile."${profileConfigDir}/oh-my-openagent.jsonc".text =
      builtins.toJSON (generateConfig { });

    # Generate opencode.jsonc in the profile directory
    xdg.configFile."${profileConfigDir}/opencode.jsonc".text =
      builtins.toJSON (generateOpenCodeConfig { });

    # TUI plugin registration - mirrors installer's addPluginToOpenCodeTuiConfig()
    xdg.configFile."${profileConfigDir}/tui.json".text =
      builtins.toJSON { plugin = cfg.tuiPlugins; };

    # Configure OpenCode settings declaratively (replaces installer steps)
    programs.opencode.settings = lib.mkMerge [
      # Disable default agents (explore, general) - mirrors installer's disableDefaultAgents()
      (lib.mkIf cfg.disableDefaultAgents {
        agent = {
          explore = { disable = true; };
          general = { disable = true; };
        };
      })

      # Enable LSP by default - mirrors installer's enableLspByDefault()
      (lib.mkIf cfg.enableLsp {
        lsp = true;
      })
    ];

    # Environment variables for background subagents - mirrors installer's background subagents setup
    home.sessionVariables = lib.mkMerge [
      (lib.mkIf cfg.backgroundSubagents {
        OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
        OPENCODE_ENABLE_EXA = "1";
      })
    ];
  };
}