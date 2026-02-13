{ pkgs, ... }:

let
  ocx = pkgs.stdenv.mkDerivation rec {
    pname = "ocx";
    version = "1.4.6"; # Check for latest version on GitHub

    src = pkgs.fetchurl {
      url = "https://github.com/kdcokenny/ocx/releases/download/v${version}/ocx-linux-x64";
      # You can get the hash via `nix-prefetch-url` or leave it empty for Nix to suggest one
      sha256 = "sha256-0000000000000000000000000000000000000000000=";
    };

    dontUnpack = true;

    installPhase = ''
      install -D $src $out/bin/ocx
    '';
  };
in
{
  home.packages = [ ocx ];

  # Ensure ocx follows XDG paths to keep your home directory clean
  home.sessionVariables = {
    OCX_CONFIG_DIR = "$XDG_CONFIG_HOME/ocx";
  };

  xdg.configFile."ocx/ocx.jsonc".text = ''
    {
      "registry": [
        "https://registry.kdco.dev"
      ],
      "telemetry": false,
      "default_profile": "default"
    }
  '';
}
