{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    spotify
    # Audio converter
    # FIXME 2025-11-18
    # ffmpeg_8
  ];
}
