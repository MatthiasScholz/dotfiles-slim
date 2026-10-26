{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  # nixpkgs' vitejs pins pnpm_10 for the build, but lets `fetchPnpmDeps`
  # default to the top-level `pnpm` (12.x). fetchPnpmDeps refuses
  # `fetcherVersion = 3` for pnpm >= 11 and throws during evaluation, which
  # aborts the whole devenv shell. Pass the pinned pnpm through explicitly.
  vitejs = pkgs.vitejs.override {
    fetchPnpmDeps = pkgs.fetchPnpmDeps.override { pnpm = pkgs.pnpm_10; };
  };
in
{
  packages = [
    # pi-web installation
    pkgs.typescript
    vitejs
    # pi-web-access video frame extraction
    pkgs.ffmpeg
    pkgs.yt-dlp
  ];

  env.KANATA_CONFIG = "config/kanata/basbousa.kbd";
  scripts.kanata-list.exec = ''
    kanata --cfg $KANATA_CONFIG --list
  '';

  scripts.kanata-check.exec = ''
    kanata --cfg $KANATA_CONFIG --check
  '';

  scripts.kanata-run.exec = ''
    kanata --cfg $KANATA_CONFIG
  '';
}
