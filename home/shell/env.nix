# Global shell aliases, session variables and PATH additions.
{
  ...
}:

{
  home = {
    shellAliases = {
      # bat --plain for unformatted cat
      catp = "bat -P";
      cat = "bat";
      # replace cd
      cd = "z";
      # HACK Trying to compile vterm for emacs
      glibtool = "libtool";
    };

    sessionVariables = {
      # TODO Set this as part of the emacs.nix
      EDITOR = "emacs";
    };

    # FIXME NOT working folder is read-only
    # Declaratively create the Terraform cache directory
    # FIXME should be only used when terraform is used - which is managed via devenv.
    # FIXME join with terraform environment variable configuration in shell.nix -> zsh
    # NOTE https://nix-community.github.io/home-manager/options.xhtml#opt-home.file
    # file = {
    #   ".terraform.d/plugin-cache" = {
    #     source = pkgs.emptyDirectory; # with standard read/write/execute permissions
    #     onChange = "chown -R ${config.home.username}:staff";
    #     recursive = true;
    #   };
    # };
  };

  # NOTE Not set when a new zsh shell is opened without logout/login as user
  home.sessionPath = [
    # FIXME set the path when respective application gets installed
    "$HOME/bin" # tfswitch
    "$HOME/go/bin" # go
  ];
}
