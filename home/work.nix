{
  config,
  lib,
  pkgs,
  ...
}:

{
  modules.gws.enable = true;

  home.packages = with pkgs; [
    zoom-us
  ];
}
