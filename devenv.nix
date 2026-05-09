{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = [
    # pi-web installation
    pkgs.typescript
    pkgs.vite
    # pi-web-access video frame extraction
    pkgs.ffmpeg
    pkgs.yt-dlp
  ];

  env.KANATA_CONFIG = "config/kanata/basbousa.kbd";
  scripts.kanata-list.exec = ''
    kanata --cfg $KANATA_CONIFG --list
  '';

  scripts.kanata-check.exec = ''
    kanata --cfg $KANATA_CONFIG --check
  '';

  scripts.kanata-run.exec = ''
    kanata --cfg $KANATA_CONFIG
  '';
}
