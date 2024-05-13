{pkgs, lib, ...}:
{
  # Emacs
  # https://github.com/nix-community/home-manager/blob/master/modules/programs/emacs.nix
  # https://github.com/nix-community/emacs-overlay
  # https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org#nixos
  programs.emacs = {
      enable = true;
  };

  # Doomemacs Prerequisites
  programs.git.enable = true;
  packages = [
      pkgs.ripgrep
      pkgs.corutils
      pkgs.fd
  ];
  # TODO Doomemacs Configuration
  # https://discourse.nixos.org/t/advice-needed-installing-doom-emacs/8806/4
  #home.file.".doom.d" = {
  #source = github.com/MatthiasScholz/...;
  #recursive = true;
  #onChange = readFile path/to/reload;
  #};
}
