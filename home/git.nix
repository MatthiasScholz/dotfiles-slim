{ pkgs, lib, ... }:
{
  home.file = {
    ".cvsignore".source = ../config/git/.cvsignore;
    ".gitconfig".source = ../config/git/.gitconfig;
  };

  # Use git-ai as a wrapper.
  # We use hiPrio for git-ai and lowPrio for the standard git package
  # to resolve binary collisions while ensuring the wrapper can call the real git.
  programs.git = {
    enable = true;
    package = lib.lowPrio pkgs.git;
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
