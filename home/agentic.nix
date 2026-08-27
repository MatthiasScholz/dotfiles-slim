{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Import our custom derivation
  pi-acp = pkgs.callPackage ./packages/pi-acp/default.nix { };
in
{
  # https://github.com/nix-community/home-manager/blob/master/modules/programs/mcp.nix
  # NOTE Reused in opencode
  programs.mcp = {
    enable = true;
    servers = {
      mermaid = {
        command = "bun";
        args = [
          "x"
          "mcp-mermaid"
        ];
      };
      devenv = {
        command = "devenv";
        args = [
          "mcp"
        ];
      };
    };
  };

  # https://github.com/nix-community/home-manager/blob/master/modules/programs/opencode.nix
  programs.opencode = {
    enable = true;

    # Dynamically select the package based on architecture
    # package =
    # if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then
    #   inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
    #   else
    #     let
    #       appVersion = "1.1.48";
    #     in
    #     # The fallback derivation for your Intel Mac Pro
    #     pkgs.stdenv.mkDerivation {
    #       pname = "opencode-baseline";
    #       # FIXME broken baseline version = "1.14.33";
    #       version = appVersion;

    #       src = pkgs.fetchzip {
    #         # FIXME broken baseline version
    #         # url =
    #         #  "https://github.com/anomalyco/opencode/releases/download/"
    #         #  + "v${version}/opencode-darwin-x64-baseline.zip";
    #         # hash = "sha256-Ux4jwHAWC2A3UDGIiu3cofjAqOAzUOLZl6zWYj6L5SY=";
    #         url =
    #           "https://github.com/anomalyco/opencode/releases/download/"
    #           + "v${appVersion}/opencode-darwin-x64.zip";
    #         # hash = pkgs.lib.fakeHash;
    #         hash = "sha256-WQERmuHfs4s8mmYCW7te8sWHEh9u8R0WkVvaErr2ZQA";
    #       };

    #       installPhase = ''
    #         mkdir -p $out/bin
    #         # Copy the extracted binary into the Nix store bin directory
    #         cp opencode $out/bin/opencode
    #         chmod +x $out/bin/opencode
    #       '';

    #       meta = {
    #         mainProgram = "opencode";
    #         description = "OpenCode AI agent";
    #       };
    #     };

    web = {
      enable = true;
      extraArgs = [
        "--hostname"
        "0.0.0.0"
        "--port"
        "4096"
        "--mdns"
      ];
    };

    enableMcpIntegration = true;

    settings = {
      autoupdate = false;
      plugin = [
        "@mohak34/opencode-notifier@latest"
        "opencode-gemini-auth@latest"
        "opencode-nanobanana@latest"
        "opencode-mem@latest"
        "@ramtinj95/opencode-tokenscope@latest"
        # NOTE OTel plugin needs additional configuration, either via opencode.jsonc or environment variables
        # TODO Add additional integration into the nix configuration
        "@devtheops/opencode-plugin-otel"
        "oh-my-opencode-slim@latest"
      ];
    };

  };

  # TODO inject my configuration repository with ocx
  # TODO only do when opencode is setup -> move opencode into separate nix file
  # Better opencode management
  imports = [
    ../modules/ocx-module.nix
    ../modules/oh-my-opencode-slim.nix
  ];

  # Enable it globally with a single flag
  programs.ocx.enable = false;

  # Enable oh-my-opencode-slim plugin
  programs.oh-my-opencode-slim = {
    enable = true;
    # Provider configuration - set to "yes" if you have access
    providers = {
      kimi = { enabled = "no"; };
      openai = { enabled = "no"; };
    };
    # Optional: enable companion desktop window
    companion = false;
    # Optional: customize models per agent
    # models = {
    #   orchestrator = "opencode/nemotron-3-ultra-free";
    #   oracle = "opencode/nemotron-3-ultra-free";
    # };
  };

  # Optional: Pre-define your favorite registries globally
  xdg.configFile."ocx/ocx.jsonc".text = builtins.toJSON {
    registries = [ "https://registry.kdco.dev" ];
    telemetry = false;
  };

  home.packages = [
    # FIXME uses postgresql test which is unsupported for darwin
    #pkgs.open-webui
    # Ggogle
    pkgs.antigravity-cli
    # PI
    # https://pi.dev, https://github.com/badlogic/pi-mono/, https://lucumr.pocoo.org/2026/1/31/pi/
    pkgs.pi-coding-agent
    pi-acp
    # AIDER
    # BROKEN aider-chat-full
    # BROKEN aider-chat-with-help
    # WORKS aider-chat
    # WORKS aider-chat-with-browser
    # WORKS
    # UNUSED aider-chat-with-playwright
    # CRUSH
    # NOTE focused on cli and api keys, no web ui
    # .https://github.com/charmbracelet/crush
    # NOTE Does not seem to support ACP (2026-01-09)
    # FIXME broken 2026-01-26
    # crush
  ];
}
