{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # NOTE not available for darwin systems -> brew
    # freecad
  ];

}
