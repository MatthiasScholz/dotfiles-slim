{ pkgs, ... }:
{
  home.file = {
    ".cvsignore".source = ../config/git/.cvsignore;
    ".gitconfig".source = ../config/git/.gitconfig;
  };

  programs.git = {
    enable = true;

    lfs.enable = true;
  };

  # TODO decide on usage
  # git alternative
  programs.jujutsu = {
    # FIXME compilation error
    enable = false;
  };

  # Manage multiple git repositories
  home.packages = with pkgs; [
    mani
    pre-commit
  ];
}
