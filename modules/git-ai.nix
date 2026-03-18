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
    assertions = [
      {
        assertion = config.programs.git.enable;
        message = "git-ai requires programs.git.enable to be true.";
      }
    ];

    home.packages = [
      (lib.hiPrio inputs.git-ai.packages.${pkgs.stdenv.hostPlatform.system}.default)
    ];

    home.file.".git-ai/config.json".text = builtins.toJSON {
      git_path = "${pkgs.git}/bin/git";
    };
  };
}
