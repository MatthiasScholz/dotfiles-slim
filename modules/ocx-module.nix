{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.ocx;

  # Map Nix system strings to OCX asset names and their hashes
  systemAssets = {
    "x86_64-linux" = {
      name = "ocx-linux-x64";
      sha256 = "sha256-KAV4qQ2tW8CIdwCbhXfX15xXfHeO4WW9FpS9v6nI9ao=";
    };
    "aarch64-linux" = {
      name = "ocx-linux-arm64";
      sha256 = "sha256-xIssJW/ARRSPcM7WGgpCqcFEK75hNMizByL08wfgaMk=";
    };
    "x86_64-darwin" = {
      name = "ocx-darwin-x64";
      sha256 = "sha256-KAV4qQ2tW8CIdwCbhXfX15xXfHeO4WW9FpS9v6nI9ao=";
    };
    "aarch64-darwin" = {
      name = "ocx-darwin-arm64";
      sha256 = "sha256-JCEldoXtfCxzjRN9PfpFLAa+RmZEdmH4x+TOb1MssOM="; # Corrected from your error!
    };
  };

  currentSystem = pkgs.stdenv.hostPlatform.system;
  asset = systemAssets."${currentSystem}" or (throw "Unsupported system: ${currentSystem}");

in
{
  options.programs.ocx = {
    enable = lib.mkEnableOption "OpenCode Extension Manager (ocx)";
    version = lib.mkOption {
      type = lib.types.str;
      default = "1.4.6";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.stdenv.mkDerivation {
        pname = "ocx";
        version = cfg.version;

        src = pkgs.fetchurl {
          url = "https://github.com/kdcokenny/ocx/releases/download/v${cfg.version}/${asset.name}";
          sha256 = asset.sha256;
        };

        dontUnpack = true;

        installPhase = ''
          install -D $src $out/bin/ocx
          chmod +x $out/bin/ocx
        '';
      })
    ];

    home.sessionVariables = {
      OCX_CONFIG_DIR = "${config.xdg.configHome}/ocx";
      OPENCODE_DATA_DIR = "${config.xdg.dataHome}/opencode";
      OPENCODE_EXTENSIONS_DIR = "${config.xdg.dataHome}/opencode/extensions";
    };
  };
}
