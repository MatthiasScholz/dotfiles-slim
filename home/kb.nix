{
  # unused: config,
  # unused: lib,
  pkgs,
  inputs,
  ...
}:

let
  # NOTE show how packages can be pinned to a specific nixpkgs version
  pkgs_ollama_0_11_0 =
    import
      (pkgs.fetchFromGitHub {
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "6c5f7adf5360eacb5320b5763d2996400d843880";
        sha256 = "sha256-FghgCtVQIxc9qB5vZZlblugk6HLnxoT8xanZK+N8qEc=";
      })
      {
        inherit (pkgs) system;
        config.allowUnfree = true;
      };

in
{
  # Options: https://github.com/nix-community/home-manager/blob/master/modules/programs/obsidian.nix
  programs.obsidian = {
    enable = true;
    cli.enable = true;

    # TODO configure theme

    defaultSettings = {
      corePlugins = [
        "backlink"
        "bases"
        "bookmarks"
        "canvas"
        "command-palette"
        "daily-notes"
        "editor-status"
        "file-explorer"
        "file-recovery"
        "global-search"
        "graph"
        "note-composer"
        "outgoing-link"
        "outline"
        "page-preview"
        "properties"
        "slash-command"
        "switcher"
        "tag-pane"
        "templates"
        "word-count"
        "zk-prefixer"
      ];
      # TODO extract the data.json for the plugins I have configured, e.g. image converter, BRAT, Agent Client
      communityPlugins = [
        "Excalidraw"
        "Auto Link Title"
        "Calendar"
        "Callout Manager"
        "Git"
        "Hider"
        "Iconize"
        "Image Converter"
        "Maps"
        "Minimal Theme Settings"
        "Natural Language Dates"
        "Recent Files"
        "Style Settings"
        "Tasks"
        "BRAT"
        "Agent Client" # BRAT
      ];
    };
  };

  home.packages = [
    # Additional packages to support plugins in obsidian
    # TODO Reconsider since switch to marimo which allows a more direct interaction
    # https://github.com/d-eniz/jupymd
    #pkgs.python313
    #pkgs.python313Packages.notebook
    #pkgs.python313Packages.jupytext
    #pkgs.python313Packages.matplotlib
    #pkgs.python313Packages.jupyterlab
    #pkgs.python313Packages.ipykernel
    # NOTE moved to use Gemini in most places
    # pkgs.ollama
    # pkgs_ollama_0_11_0
    # Knowledge management via LSP
    # https://oxide.md/Home
    pkgs.markdown-oxide
    # Markdown support

    # Render mermaid diagrams, provides mmdc
    pkgs.mermaid-cli
    # library
    # NOTE broken for macosx
    # pkgs.calibre
  ];

  # TODO Install some models
  # Obsidian
  # - nomic-embed-text
  # - llama3.1
  # - gemma2
  # Emacs - Might need to be setup in emacs.nix
  # - zephyr
  #

  /*
    # FIXME syntax error
      # Get ollama launched
      # https://www.danielcorin.com/til/nix-darwin/launch-agents/
      # NOTE service execution is os dependent
      # TODO Add support for linux os Consider connection if os independency should be achieved
      # Creates a plist file at `~/Library/LaunchAgents``
      # State: `launchctl blame gui/501/org.nixos.ollama-serve`
      launchd.user.agents = {
            ollama-serve = {
              command = "${pkgs.ollama}/bin/ollama serve";
              serviceConfig = {
                KeepAlive = true;
                RunAtLoad = true;
                StandardOutPath = "/tmp/ollama.out.log";
                StandardErrorPath = "/tmp/ollama.err.log";
                EnvironmentVariables = {
                  OLLAMA_ORIGINS = "moz-extension://*,chrome-extension://*,safari-web-extension://*";
                };
              };
            };
      };
  */

  # FIXME not working, missing homebrew context
  #homebrew = {
  #  casks = [
  #    "obsidian"
  #    "msty"
  #  ];
  #};

}
