# OpenCode core: the v2 package, its web service (attached to by OpenChamber)
# and the pinned plugin list.
{
  pkgs,
  ...
}:

let
  # Pinned OpenCode plugin versions (refreshed via `make update`)
  pluginVersions = import ../../modules/opencode-plugin-versions.nix;
in
{
  # https://github.com/nix-community/home-manager/blob/master/modules/programs/opencode.nix
  programs.opencode = {
    enable = true;

    # OpenCode v2. nixpkgs `pkgs.opencode` still tracks the 1.x line, whose
    # server API OpenChamber v2 rejects. packages/opencode packages the
    # published @opencode/cli v2 artifact (per-arch hashes inside). See
    # docs/adr/0009-opencode-v2-from-npm.md.
    package = pkgs.callPackage ../../packages/opencode { };

    web = {
      enable = true;
      # NOTE v2 `serve` has no `--mdns` flag (v1 did); the LAN/mDNS discovery
      # moved to the background `service` subsystem.
      extraArgs = [
        "--hostname"
        "0.0.0.0"
        "--port"
        "4096"
      ];
      # OpenCode v2 requires a server password. The agenix-backed
      # `environmentFile` wait shim is owned by programs.openchamber.attach in
      # the openchamber slice, so that both halves of the attach contract live
      # with the module (lib/launchd.nix). NOTE darwin-only: on Linux systemd
      # would parse this as a KEY=VALUE EnvironmentFile.
    };

    enableMcpIntegration = true;

    settings = {
      autoupdate = false;
      plugin = [
        # Pinned versions (updated via make update -> scripts/update-opencode-plugin-versions.sh)
        "opencode-gemini-auth@${pluginVersions."opencode-gemini-auth"}"
        #"opencode-nanobanana@${pluginVersions."opencode-nanobanana"}"
        "opencode-mem@${pluginVersions."opencode-mem"}"
        "@ramtinj95/opencode-tokenscope@${pluginVersions."@ramtinj95/opencode-tokenscope"}"
        # NOTE OTel plugin needs additional configuration, either via opencode.jsonc or environment variables
        # TODO Add additional integration into the nix configuration
        "@devtheops/opencode-plugin-otel@${pluginVersions."@devtheops/opencode-plugin-otel"}"
        "oh-my-opencode-slim@${pluginVersions."oh-my-opencode-slim"}"
      ];
    };

  };
}
