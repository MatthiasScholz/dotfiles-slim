{
  config,
  lib,
  pkgs,
  ...
}:

{
  modules.gws.enable = true;

  home.packages = with pkgs; [
    # FIXME outdated version
    # zoom-us
  ];
}
