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
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.git-ai.packages.${pkgs.system}.default
    ];

    # Optional: ensure it's integrated with zsh if needed
    # programs.zsh.initExtra = ''
    #   # any git-ai specific shell setup
    # '';
  };
}
