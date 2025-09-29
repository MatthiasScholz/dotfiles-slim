{ config, pkgs, ... }:

{

  home.packages = with pkgs; [
    # Focus on Emacs, Cline and Zed
    #code-cursor
    # VS Code for AI coding agent trials
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
    aider-chat-with-playwright
    # Focus on aider
    gemini-cli
    # .https://github.com/charmbracelet/crush
    crush

  ];

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
}
