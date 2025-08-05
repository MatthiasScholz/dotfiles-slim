{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # per project, vcs specific development environment setup
    # NOTE in order to use cachix binary caching the nix installations configuration has to be update:
    # determinate-nixd upgrade --extra-conf " extra-substituters = https://devenv.cachix.org extra-trusted-public-keys =  devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    devenv
    # alternative with hopefully better flake support
    # https://www.jetify.com/docs/devbox/guides/using_flakes/
    devbox
  ];

}
