{
  # unused: config,
  # unused: lib,
  pkgs,
  inputs,
  ...
}:

let
  # NOTE show how packages can be pinned to a specific nixpkgs version
  # NOTE obsidian 1.8.9 was broken on mac
  # unstable branch
  pkgs_obsidian_1_8_7 =
    import
      (pkgs.fetchFromGitHub {
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "31b5f3ba6361adde901c0c83b02f13212ccdc01f";
        sha256 = "iR9wRkor7/lKycBZ/w1rJWanV/Wd8bcIQALOl7jJmoM=";
      })
      {
        inherit (pkgs) system;
        config.allowUnfree = true;
      };
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
  home.packages = [
    pkgs.obsidian
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
