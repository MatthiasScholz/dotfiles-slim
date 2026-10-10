# Agentic CLI packages installed into the home profile.
{
  pkgs,
  ...
}:

let
  # Import our custom derivation
  pi-acp = pkgs.callPackage ../packages/pi-acp/default.nix { };
in
{
  home.packages = [
    # FIXME uses postgresql test which is unsupported for darwin
    #pkgs.open-webui
    # Google
    pkgs.antigravity-cli
    # PI
    # https://pi.dev, https://github.com/badlogic/pi-mono/, https://lucumr.pocoo.org/2026/1/31/pi/
    pkgs.pi-coding-agent
    pi-acp
    # Claude Code
    pkgs.claude-code
    pkgs.claude-agent-acp
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
