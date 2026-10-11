# zsh configuration. The emacs-vterm `initContent` lives in vterm.nix.
{
  config,
  lib,
  ...
}:

{
  programs = {
    # fish
    # TODO decide on use
    # fish = {
    #   enable = true;

    #   interactiveShellInit = ''
    #     set fish_greeting # N/A
    #   '';

    #   plugins = [
    #     {
    #       # TODO: Remove this
    #       name = "fish-asdf";
    #       src = pkgs.fetchFromGitHub {
    #         owner = "rstacruz";
    #         repo = "fish-asdf";
    #         rev = "5869c1b1ecfba63f461abd8f98cb21faf337d004";
    #         sha256 = "39L6UDslgIEymFsQY8klV/aluU971twRUymzRL17+6c=";
    #       };
    #     }
    #     {
    #       name = "nix-env";
    #       src = pkgs.fetchFromGitHub {
    #         owner = "lilyball";
    #         repo = "nix-env.fish";
    #         rev = "7b65bd228429e852c8fdfa07601159130a818cfa";
    #         hash = "sha256-RG/0rfhgq6aEKNZ0XwIqOaZ6K5S4+/Y5EEMnIdtfPhk=";
    #       };
    #     }
    #   ];
    # };

    # ZSH
    zsh.enable = true;

    # NOTE 2026-01-03 Updated behavior of configuration file management
    zsh.dotDir = "${config.xdg.configHome}/zsh";
    # TODO move terraform configuration into the related template flake
    # FIXME create the cache folder with nix
    # TODO move docker configuration into the related template flake - if possible
    # Configure colima
    zsh.envExtra = ''
      export DOCKER_HOST=unix://$HOME/.colima/docker.sock
      export TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache
    '';

    zsh.profileExtra = ''
      [ -r ~/.nix-profile/etc/profile.d/nix.sh ] && source  ~/.nix-profile/etc/profile.d/nix.sh
      export XCURSOR_PATH=$XCURSOR_PATH:/usr/share/icons:~/.local/share/icons:~/.icons:~/.nix-profile/share/icons
    '';

    zsh.autosuggestion = {
      enable = true;
      strategy = [
        "match_prev_cmd"
        "completion"
      ];
    };

    zsh.enableCompletion = true;

    zsh.antidote = {
      enable = true;
      useFriendlyNames = true;
      plugins = [
        # Completion
        # run towards the TOP of your .zsh_plugins.txt before any compdef calls
        "mattmc3/ez-compinit"
      ];
    };

    # Define shell aliases
    # TODO Think about how to make dependent on actual use
    #      For now tools are defined as global packages in .fleek.yml
    zsh.shellAliases = {
      # NOTE Defined here because of missing direnv support
      #      Should not harm either - just points nowhere
      # Terraform
      tf = "terraform";
      tfi = "terraform init -upgrade";
      tfp = "terraform plan";
      tfps = "terraform plan -no-color | grep -E '^[[:punct:]]+ resource|~ resource|\+ resource |Plan' | sort";
      # Terramate
      tmg = "terramate generate";
      tmi = "terramate run -- terraform init -upgrade";
      # TODO Incorporate tf-summarize
      #tmp = "terramate run -- sh -c ""pwd && terraform plan""";
      tmp = "terramate run -- terraform plan";

      tma = "terramate run -- terraform apply";
      tmaa = "terramate run -- terraform apply -auto-approve";
      tmclone = "terramate experimental clone";
      # Project dependent
      #apip = "restish tsp";
      #apis = "restish tss";
      #apie = "restish tse";
      #apil = "restish tsl";
    };

    # let the terminal track the current working directory
    zsh.enableVteIntegration = true;

    # TODO https://developer.1password.com/docs/cli/shell-plugins/nix/
    #imports = [ inputs._1password-shell-plugins.hmModules.default ];
    #programs._1password-shell-plugins = {
    #  # enable 1Password shell plugins for bash, zsh, and fish shell
    #  enable = true;
    #  # the specified packages as well as 1Password CLI will be
    #  # automatically installed and configured to use shell plugins
    #  plugins = with pkgs; [ gh awscli2 cachix ];
    #};

    # TODO Check if needed
    bash.enable = true;
    # TODO Try
    #     bashrcExtra = ''
    #  export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
    #'';
  };
}
