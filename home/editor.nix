{ config, pkgs, ... }:

{

  home.packages = with pkgs; [
    # Focus on Emacs, Cline and Zed
    #code-cursor
    # VS Code for AI coding agent trials
    # TODO Migrate vscode stuff to different file
    vscode
    #vscode-with-extensions
    # FIXME hash mismatch: vscode-extensions.continue.continue
    vscode-extensions.hashicorp.hcl
    vscode-extensions.hashicorp.terraform
    vscode-extensions.golang.go
    # Cline MCP servers prerequisities
    nodejs
    # FIXME not working: nodePackages_latest."@modelcontextprotocol/server-filesystem"
    uv
    # LSP for nix compatible wih zed
    nil
    # CLI AI Agents
    # FIXME broken
    # BROKEN aider-chat-full
    # BROKEN aider-chat-with-help
    # WORKS aider-chat
    # WORKS aider-chat-with-browser
    # WORKS
    # UNUSED aider-chat-with-playwright
    # Focus on aider
    gemini-cli
    # .https://github.com/charmbracelet/crush
    # NOTE Does not seem to support ACP (2026-01-09)
    # FIXME broken 2026-01-26
    # crush
    # FIXME there is custom files manually created in
    # TODO incorporate my personal global opencode configuration
    # ~/.config/opencode/agent/docs-writer.md
    # from
    # https://opencode.ai/docs/agents/#examples
    opencode
    # Modable Development
    # TODO unsupported on darwin
    # https://search.nixos.org/packages?channel=unstable&show=glamoroustoolkit&query=glamoroustoolkit
    # glamoroustoolkit
  ];

  # Better opencode management
  imports = [
    ../modules/ocx-module.nix
  ];

  # Enable it globally with a single flag
  programs.ocx.enable = true;

  # Optional: Pre-define your favorite registries globally
  xdg.configFile."ocx/ocx.jsonc".text = builtins.toJSON {
    registries = [ "https://registry.kdco.dev" ];
    telemetry = false;
  };

  /*
    FIXME not working "No such file or directory" - test_open_paths_action
    # https://github.com/NixOS/nixpkgs/blob/nixpkgs-unstable/pkgs/by-name/ze/zed-editor/package.nix
    # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zed-editor.enable
    programs.zed-editor = {
      enable = true;

      # FIXME using any of these configuration settings make the activate stuck.
      # extensions = [
      #   "basher"
      #   "dockerfile"
      #   "docker-compose"
      #   "gemini"
      #   "golangci-lint"
      #   "gosum"
      #   "http"
      #   "make"
      #   "mermaid"
      #   "nix"
      #   "rainbow-csv"
      #   "rego"
      #   "risor"
      #   "terraform"
      #   "markdown-oxide"
      # ];

      #   userSettings = {
      #     # https://zed.dev/docs/configuring-zed#direnv-integration
      #     load_direnv = "direct";
      #     autosave = "on_focus_change";

      #     agent = {
      #       default_model = {
      #         provider = "google.ai";
      #         model = "gemini-2.5-pro-preview-05-06";
      #       };
      #     };
      #   };
    };
  */
}
