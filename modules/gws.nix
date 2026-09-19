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
      (import ../packages/gws.nix {
        inherit pkgs lib;
        gws-cli-src = inputs.gws-cli-src;
      })
    ];
  };
}
