{
  pkgs,
  # unused: lib,
  # unused: inputs,
  ...
}:
{
  # Emacs
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.emacs.enable
  # https://github.com/nix-community/home-manager/blob/master/modules/programs/emacs.nix
  # https://github.com/nix-community/emacs-overlay
  # https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org#nixos
  programs.emacs = {
    enable = true;
    # setting emacs specific binary
    #package = (
    #  # unsecure: pkgs.emacs-macport.override {
    #  pkgs.emacs30.override {
    #    # unknown: withModules = true;
    #    # unsupported for mac: withXwidgets = true;
    #  }
    #);
    # TODO Check if needed
    extraPackages = epkgs: [ epkgs.vterm ];
  };
  # NOThttps://github.com/ljos/jq-modeEvscode-langservers-extracted vterm support requires compilation
  # requires: libtool, brew:libvterm
  # command for compilation:
  # . Ensure existing alias of `glibtool` to `libtool` (part of shell.nix already)
  # . Find path of the emacs module -> run vterm failing compilation within emacs
  # . Compile outside of emacs in the terminal with the <emacs-vterm>/build folder
  # . `cmake -DLIBVTERM_INCLUDE_DIR=/opt/homebrew/Cellar/libvterm/0.3.3/include -DLIBVTERM_LIBRARY=/opt/homebrew/Cellar/libvterm/0.3.3/lib/libvterm.0.dylib ..`
  # . `make`
  # SEE: cmake configuration parameters: https://github.com/akermu/emacs-libvterm/blob/master/CMakeLists.txt

  # Doomemacs
  # https://github.com/hlissner/dotfiles/blob/master/modules/editors/emacs.nix
  # .Doomemacs Prerequisites
  programs.git = {
    enable = true;
    # NOTE git 2.45.1 seems to have an issue on darwin systems
    #package = inputs.nixpkgs-stable.git;
  };
  home.packages = with pkgs; [
    (ripgrep.override { withPCRE2 = true; })
    coreutils
    fd
    binutils
    gnutls
    fd
    imagemagick
    zstd
    sqlite
    editorconfig-core-c
    # icons for the themes
    # TODO emacs: understand if all-the-icons is obsolete
    emacs-all-the-icons-fonts
    # TODO emacs: move font configuration outside, since there are now many
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    # to build vterm
    cmake
    libtool # missing alias to glibtool need for vterm compilation
    #libvterm # not supported on darwin
    # flyspell
    ispell
    # :lang markdown
    # https://docs.doomemacs.org/latest/modules/lang/markdown/
    go-grip
    # :lang nix
    # nixfmt - package relabeling ongoing (2024-06-24)
    nixfmt-rfc-style
    # :lang sh
    shfmt
    shellcheck
    bash-language-server
    # :emacs dired
    #ls
    # :completion vertico
    #grep # with PCRE lookaheads
    # difftastic
    difftastic
    # json
    vscode-langservers-extracted
    # compress undo history
    # https://docs.doomemacs.org/v21.12/modules/emacs/undo/
    zstd
    # markdown preview
    pandoc
    # Detect fonts
    fontconfig
    # Dired features
    poppler
    # Samba Share Connect Support
    samba
    # Debugger
    lldb
    # FIXME debug emacs issue with latest macosx update
    libgccjit
    # :lang lua
    lua-language-server
  ];
  # TODO .Doomemacs Installation

  # FIXME .Doomemacs Configuration
  # https://discourse.nixos.org/t/advice-needed-installing-doom-emacs/8806/4
  #home.file.".doom.d" = {
  #  source = builtins.fetchGit "https://github.com/MatthiasScholzTW/doom-emacs-config.git";
  #  recursive = true;
  #  # TODO onChange = readFile path/to/reload;
  #};
  # TODO Try
  #   # Doom private config
  # xdg.configFile."doom".source = ./doom; TODO Reference repository

  programs.zsh.initContent = ''
      # TODO Check if doomemacs already provides this functionality somehow, via :os tty
      # Use vterm provide configuration files to configure integration
      # https://github.com/akermu/emacs-libvterm?tab=readme-ov-file#shell-side-configuration-files
      if [[ "$INSIDE_EMACS" = 'vterm' ]] \
        && [[ -n $\{EMACS_VTERM_PATH\} ]] \
        && [[ -f $\{EMACS_VTERM_PATH\}/etc/emacs-vterm-zsh.sh ]]; then
    	  source $\{EMACS_VTERM_PATH\}/etc/emacs-vterm-zsh.sh
      fi
  '';
}
