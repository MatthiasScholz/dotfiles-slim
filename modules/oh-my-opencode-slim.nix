{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.programs.oh-my-opencode-slim;

  # Pinned plugin versions (refreshed via `make update` -> scripts/update-opencode-plugin-versions.sh)
  pluginVersions = import ./opencode-plugin-versions.nix;

  # Plugin spec with the pinned version, e.g. "oh-my-opencode-slim@2.2.17"
  pluginSpec = "oh-my-opencode-slim@${cfg.version}";

  # Source: https://github.com/alvinunreal/oh-my-opencode-slim/blob/master/docs/opencode-zen-free-preset.md
  defaultPreset = "opencode-go";

  defaultPresets = {
    "opencode-go" = {
      orchestrator = {
        model = "opencode/x-preview-f-free";
        variant = "high";
        temperature = 0.4;
        skills = [ "*" ];
        mcps = [
          "*"
          "!context7"
        ];
      };
      oracle = {
        model = "opencode/big-pickle";
        temperature = 0.4;
        variant = "max";
        skills = [ "simplify" ];
        mcps = [ ];
      };
      explorer = {
        model = "opencode/nemotron-3.5-lightning-free";
        temperature = 0.2;
        skills = [ ];
        mcps = [ ];
      };
      librarian = {
        model = "opencode/nemotron-3.5-lightning-free";
        temperature = 0.2;
        skills = [ ];
        mcps = [
          "context7"
          "gh_grep"
        ];
      };
      designer = {
        model = "opencode/mimo-v2.5-free";
        temperature = 0.3;
        variant = "medium";
        skills = [ ];
        mcps = [ ];
      };
      fixer = {
        model = "opencode/hy3-free";
        variant = "high";
        temperature = 0.2;
        skills = [ ];
        mcps = [ ];
      };
      observer = {
        model = "opencode/mimo-v2.5-free";
        temperature = 0.2;
        variant = "low";
        skills = [ ];
        mcps = [ ];
      };
    };

    "openrouter" = {
      orchestrator = {
        model = "opencode/x-preview-f-free";
        variant = "high";
        temperature = 0.4;
        skills = [ "*" ];
        mcps = [
          "*"
          "!context7"
        ];
      };
      oracle = {
        model = "opencode/big-pickle";
        temperature = 0.4;
        variant = "max";
        skills = [ "simplify" ];
        mcps = [ ];
      };
      explorer = {
        model = "opencode/nemotron-3.5-lightning-free";
        temperature = 0.2;
        skills = [ ];
        mcps = [ ];
      };
      librarian = {
        model = "opencode/nemotron-3.5-lightning-free";
        temperature = 0.2;
        skills = [ ];
        mcps = [
          "context7"
          "gh_grep"
        ];
      };
      designer = {
        model = "opencode/mimo-v2.5-free";
        temperature = 0.3;
        variant = "medium";
        skills = [ ];
        mcps = [ ];
      };
      fixer = {
        model = "opencode/hy3-free";
        variant = "high";
        temperature = 0.2;
        skills = [ ];
        mcps = [ ];
      };
      observer = {
        model = "opencode/mimo-v2.5-free";
        temperature = 0.2;
        variant = "low";
        skills = [ ];
        mcps = [ ];
      };
    };

    # Every agent runs on an opencode free model (no usage cost)
    "opencode-zen-free" = {
      orchestrator = {
        model = "opencode/x-preview-f-free";
        variant = "high";
        temperature = 0.4;
        skills = [ "*" ];
        mcps = [
          "*"
          "!context7"
        ];
      };
      oracle = {
        model = "opencode/big-pickle";
        temperature = 0.4;
        variant = "max";
        skills = [ "simplify" ];
        mcps = [ ];
      };
      explorer = {
        model = "opencode/nemotron-3.5-lightning-free";
        temperature = 0.2;
        skills = [ ];
        mcps = [ ];
      };
      librarian = {
        model = "opencode/nemotron-3.5-lightning-free";
        temperature = 0.2;
        skills = [ ];
        mcps = [
          "context7"
          "gh_grep"
        ];
      };
      designer = {
        model = "opencode/mimo-v2.5-free";
        temperature = 0.3;
        variant = "medium";
        skills = [ ];
        mcps = [ ];
      };
      fixer = {
        model = "opencode/hy3-free";
        variant = "high";
        temperature = 0.2;
        skills = [ ];
        mcps = [ ];
      };
      observer = {
        model = "opencode/mimo-v2.5-free";
        temperature = 0.2;
        variant = "low";
        skills = [ ];
        mcps = [ ];
      };
    };
  };

  # Profile name (defaults to "personal")
  profileName = cfg.profile;

  # Profile-specific config directory (opencode profile dirs are PLURAL: profiles/<name>)
  profileConfigDir = "opencode/profiles/${profileName}";

  # Generate the oh-my-opencode-slim.json "lite config" (preset-based format the plugin reads)
  generateConfig = _: {
    "$schema" = "https://unpkg.com/oh-my-opencode-slim@latest/oh-my-opencode-slim.schema.json";
    preset = cfg.preset;
    presets = cfg.presets;
  };

in
{
  options.programs.oh-my-opencode-slim = {
    enable = lib.mkEnableOption "oh-my-opencode-slim agent orchestration plugin";

    # Pinned plugin version (default from modules/opencode-plugin-versions.nix)
    version = lib.mkOption {
      type = lib.types.str;
      default = pluginVersions."oh-my-opencode-slim";
      description = "Pinned oh-my-opencode-slim version (refreshed by make update)";
    };

    # Plugins registered in the profile's tui.json (TUI version badge)
    tuiPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ pluginSpec ];
      description = "Plugins to register in the profile's tui.json";
    };

    profile = lib.mkOption {
      type = lib.types.str;
      default = "personal";
      description = "OpenCode profile name (e.g., 'personal', 'work', 'dev')";
    };

    # Active preset name
    preset = lib.mkOption {
      type = lib.types.str;
      default = defaultPreset;
      description = "Active preset name (must exist in presets)";
    };

    # Preset definitions: preset name -> agent name -> { model, variant, temperature, skills, mcps }
    presets = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = defaultPresets;
      description = "Agent model presets (see opencode-zen-free-preset.md)";
    };

    # Optional: enable the desktop companion status window
    companion = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the companion desktop status window";
    };

    # OpenCode settings managed by the plugin
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
    # Ensure bun is available for the plugin (if needed at runtime)
    home.packages = [
      pkgs.bun
      pkgs.nodejs
    ];

    # Generate oh-my-opencode-slim.json (lite config) in profile directory
    xdg.configFile."${profileConfigDir}/oh-my-opencode-slim.json".text = builtins.toJSON (
      generateConfig { }
    );

    # Also create a project-local config for development
    xdg.configFile.".opencode/oh-my-opencode-slim.json".text = builtins.toJSON (generateConfig { });

    # TUI plugin registration - mirrors installer's addPluginToOpenCodeTuiConfig()
    xdg.configFile."${profileConfigDir}/tui.json".text = builtins.toJSON { plugin = cfg.tuiPlugins; };

    # Configure OpenCode settings declaratively (replaces installer steps)
    programs.opencode.settings = lib.mkMerge [
      # Disable default agents (explore, general) - mirrors installer's disableDefaultAgents()
      (lib.mkIf cfg.disableDefaultAgents {
        agent = {
          explore = {
            disable = true;
          };
          general = {
            disable = true;
          };
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
