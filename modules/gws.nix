{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.gws;
in
{
  options.modules.gws = {
    enable = lib.mkEnableOption "Google Workspace CLI (gws) integration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.google-cloud-sdk
      inputs.gws-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
