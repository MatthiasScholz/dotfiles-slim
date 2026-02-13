{ pkgs, ... }:
{
  home.file = {
    ".cvsignore".source = ../config/git/.cvsignore;
    ".gitconfig".source = ../config/git/.gitconfig;
  };

  # FIXME git and git-ai conflict since git-ai is a wrapper around git they use the same binary name.
  # TODO check if git-ai is a wrapper or if it ships the git binary as well
  programs.git = {
    enable = true;
    # TODO Inject from profile Configuration
    settings.user.name = "MatthiasScholzTW";
    settings.init.defaultBranch = "main";
  };

  modules.git-ai.enable = true;

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
