{ lib, buildNpmPackage }:

buildNpmPackage {
  pname = "pi-acp";
  version = "1.0.0";

  src = ./.;

  # This is a dummy hash.
  # Nix will fail on the first run and provide the correct hash.
  # Replace this value with the hash from the error message.
  # npmDepsHash = lib.fakeHash;
  npmDepsHash = "sha256-ZknBgMwEUmiIUo5yUGF5S8mzybGxxKRzewPRBYx6IJg=";

  dontNpmBuild = true;

  # Manually expose the binary to the system path
  postInstall = ''
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/pi-acp/node_modules/.bin/pi-acp $out/bin/pi-acp
  '';
}
