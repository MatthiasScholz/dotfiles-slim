# OpenChamber - agentic development environment on top of OpenCode.
# The `modules/openchamber.nix` option declaration is imported by default.nix.
{
  config,
  ...
}:

{
  # OpenChamber - agentic development environment on top of OpenCode
  # https://github.com/openchamber/openchamber (CLI/Web installed from the
  # published @openchamber/web npm package; drives the programs.opencode above)
  # Runs as a launchd LaunchAgent, the declarative equivalent of upstream's
  # `openchamber startup enable`.
  #
  # Bound to 0.0.0.0 so other devices on the LAN (desktop/mobile/PWA) can reach
  # it, which OpenChamber only allows with UI auth — hence the agenix password
  # below (ADR-0004). The agenix CLI defaults to ~/.ssh/id_rsa|id_ed25519, so
  # pass the repo's age key explicitly (secrets.nix holds the recipients):
  #   read:   make openchamber-password
  #   rotate: agenix -e secrets/openchamber-web.age -i ~/.config/sops/age/keys.txt
  # The decrypted copy is also at ~/.agenix/openchamber-web after a switch.
  age.secrets."openchamber-web" = {
    file = ../../secrets/openchamber-web.age;
    path = "${config.home.homeDirectory}/.agenix/openchamber-web";
  };

  # Shared OpenCode v2 server password (see ADR-0009): read by the OpenCode
  # web service and by the OpenChamber LaunchAgent (modules/openchamber.nix
  # `attach.serverPasswordFile`). Content is a shell `export OPENCODE_SERVER_PASSWORD=...`.
  age.secrets."opencode-server" = {
    file = ../../secrets/opencode-server.age;
    path = "${config.home.homeDirectory}/.agenix/opencode-server";
  };

  programs.openchamber = {
    enable = true;
    port = 3000;
    launchd.enable = true;
    host = "0.0.0.0";
    uiPasswordFile = config.age.secrets."openchamber-web".path;

    # Attach to the OpenCode server programs.opencode already runs on :4096
    # instead of supervising a second one, authenticating with the shared
    # server password. The module owns both sides of the contract: the
    # LaunchAgent wrapper that sources `serverPasswordFile` and the
    # OpenCode-side `environmentFile` wait shim (ADR-0009). Deterministic
    # replacement for the auto-detect step documented in modules/openchamber.nix.
    attach = {
      enable = true;
      host = "http://localhost:4096";
      serverPasswordFile = config.age.secrets."opencode-server".path;
    };

    # Voice output: allow a remote OpenAI-compatible TTS server. OpenRouter's
    # `/audio/speech` endpoint lives at https://openrouter.ai/api/v1, and the
    # server refuses remote custom speech URLs on a CLI-launched instance
    # unless this flag is set (the desktop-embedded runtime allows them by
    # default, this one does not). Local-only hosts work without it.
    environment.OPENCHAMBER_ALLOW_REMOTE_OPENAI_COMPAT_URLS = "true";

    # Run the separately installed desktop app (Homebrew cask `openchamber`)
    # as a client of this server instead of as a second embedded server — one
    # server owns the port and ~/.config/openchamber, the desktop loads its
    # bundled UI and talks to this API. See ADR-0008.
    desktopClient.enable = true;

    # Headless API-only server (no browser UI assets):
    # apiOnly = true;
  };
}
