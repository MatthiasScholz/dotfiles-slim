# Shell tooling: the pinned warp-terminal, the shell package list and the
# CLI replacements (ls/cat/history/cd).
{
  pkgs,
  ...
}:

let
  # NOTE show how packages can be pinned to a specific nixpkgs version
  # NOTE obsidian 1.8.9 was broken on mac
  # unstable branch
  pkgs_warp-terminal_17 =
    import
      (pkgs.fetchFromGitHub {
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "a02b9f5982d1be8ebdaf1fb368c1ddb24793176a";
        sha256 = "sha256-NWFyaZ4AWTVJzB+xYSkEgvtZ1YewsYe/2UtBTLi8PPg";
      })
      {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
in
{
  home.packages = [
    # FIXME Currently broken because of missing filesystem support warp-terminal
    pkgs_warp-terminal_17.warp-terminal
    pkgs.tree
  ];

  programs = {
    # Helper
    # .Replacement for 'ls'
    eza = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
    };
    # .Replacement for 'cat'
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
      };
    };
    # Shell history replacement
    atuin.enable = true;
    # Smarter 'cd' with 'z'
    zoxide.enable = true;
    dircolors.enable = true;

    ripgrep.enable = true;
  };
}
