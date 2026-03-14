{
  config,
  lib,
  pkgs,
  ...
}:

let
  # NOTE show how packages can be pinned to a specific nixpkgs version
  # unstable branch
  pkgs_devenv_1_11_2 =
    import
      (pkgs.fetchFromGitHub {
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "f109adf791ee28d3bca68acbfaf0bdc9fe75dad8"; # 1.11.2
        sha256 = "sha256-NWFyaZ4AWTVJzB+xYSkEgvtZ1YewsYe/2UtBTLi8PPg";
      })
      {
        inherit (pkgs) system;
        config.allowUnfree = true;
      };
in
{
  home.packages = [
    # per project, vcs specific development environment setup
    # FIXME --extra-conf not working!
    # NOTE in order to use cachix binary caching the nix installations configuration has to be update:
    # determinate-nixd upgrade --extra-conf " extra-substituters = https://devenv.cachix.org extra-trusted-public-keys =  devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    # FIXME latest devenv 2.0.3 broken
    # pkgks.devenv
    pkgs_devenv_1_11_2.devenv
    # NOTE not so nice to use because of JSON format and scripting in JSON.
    # alternative with hopefully better flake support
    # https://www.jetify.com/docs/devbox/guides/using_flakes/
    # devbox
  ];

}
