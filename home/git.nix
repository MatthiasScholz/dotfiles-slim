{ pkgs, ... }:
{
  home.file = {
    ".cvsignore".source = ../config/git/.cvsignore;
    ".gitconfig".source = ../config/git/.gitconfig;
  };

  programs.git = {
    enable = true;
    # TODO Inject from profile Configuration
    settings.user.name = "MatthiasScholzTW";
    settings.init.defaultBranch = "main";
  };

  # Use difftastic as default git diff viewer
  programs.difftastic = {
    enable = true;
    git = {
      enable = true;
      diffToolMode = true;
    };
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
