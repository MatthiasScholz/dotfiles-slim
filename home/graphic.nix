{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # UNUSED inkscape
    # FIXME broken
    # rapidraw
  ];

}
