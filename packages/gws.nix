# Google Workspace CLI (gws), built from the upstream source tree.
# NOTE We do not use the upstream flake's `packages.default` because its
# flake.nix evaluates the deprecated `stdenv.isLinux`/`stdenv.isDarwin`
# attributes, which spams evaluation warnings. This expression mirrors
# the upstream build but uses `stdenv.hostPlatform` checks.
{
  pkgs,
  lib,
  gws-cli-src,
}:

let
  cargoToml = builtins.fromTOML (
    builtins.readFile (gws-cli-src + "/crates/google-workspace-cli/Cargo.toml")
  );
in
pkgs.rustPlatform.buildRustPackage {
  pname = "gws";
  version = cargoToml.package.version;

  src = gws-cli-src;

  cargoLock.lockFile = gws-cli-src + "/Cargo.lock";

  # On Linux, keyring often needs libsecret; on macOS, the Security framework.
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs =
    lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.libsecret ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      pkgs.libiconv
      pkgs.apple-sdk
    ];

  # Tests are disabled by default in buildRustPackage if not specified,
  # but we'll be explicit. Some tests might require network.
  doCheck = false;

  meta.mainProgram = "gws";
}
