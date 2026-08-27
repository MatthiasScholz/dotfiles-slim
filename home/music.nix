{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    spotify
    tidal
    # Audio converter
    # FIXME 2025-11-18
    # ffmpeg_8
  ];
}
