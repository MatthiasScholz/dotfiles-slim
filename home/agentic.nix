{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Import our custom derivation
  pi-acp = pkgs.callPackage ./packages/pi-acp/default.nix { };
in
{
  home.packages = [
    # FIXME uses postgresql test which is unsupported for darwin
    #pkgs.open-webui
    # FIXME package seems to be broken app does not start
    # pkgs.opencode-desktop
    pkgs.gemini-cli
    # https://pi.dev, https://github.com/badlogic/pi-mono/, https://lucumr.pocoo.org/2026/1/31/pi/
    pkgs.pi-coding-agent
    pi-acp
  ];
}
