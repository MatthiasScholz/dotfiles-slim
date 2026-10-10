# ocx (OpenCode Extension Manager): the global enable flag and registry config.
# The `modules/ocx-module.nix` option declaration is imported by default.nix.
{
  ...
}:

{
  # TODO inject my configuration repository with ocx

  # Enable it globally with a single flag
  programs.ocx.enable = false;

  # Optional: Pre-define your favorite registries globally
  xdg.configFile."ocx/ocx.jsonc".text = builtins.toJSON {
    registries = [ "https://registry.kdco.dev" ];
    telemetry = false;
  };
}
