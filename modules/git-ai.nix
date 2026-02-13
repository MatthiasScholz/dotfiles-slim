{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.git-ai;
in
{
  options.modules.git-ai = {
    enable = lib.mkEnableOption "git-ai integration";
    zshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Zsh integration (aliases and completions).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.git-ai.packages.${pkgs.system}.default
    ];

    home.file.".git-ai/config.json".text = builtins.toJSON {
      git_path = "${pkgs.git}/bin/git";
    };

    programs.zsh = lib.mkIf cfg.zshIntegration {
      shellAliases = {
        git = "git-ai";
      };
      # initContent = ''
      #   # Use git completion for git-ai
      #   if (( $+functions[compdef] )); then
      #     compdef git-ai=git
      #   fi
      # '';
    };
  };
}
