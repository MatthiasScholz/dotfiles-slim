{ config, lib, ... }:

let
  # The OpenChamber desktop app and the Nix-packaged @openchamber/web server
  # must move together: the desktop is a client of the server (ADR-0008). The
  # cask version is owned by the pinned homebrew-cask tap; the server version by
  # packages/openchamber/package-lock.json (the source default.nix derives its
  # version from). Warn when a `make update` advances the tap without a matching
  # server bump, so the two do not silently drift.
  openchamberCaskVersion =
    let
      caskText = builtins.readFile "${config.nix-homebrew.taps."homebrew/homebrew-cask"}/Casks/o/openchamber.rb";
      parts = builtins.split ''version "([^"]+)"'' caskText;
    in
    builtins.head (builtins.elemAt parts 1);

  openchamberServerVersion =
    (builtins.fromJSON (builtins.readFile ../packages/openchamber/package-lock.json))
    .packages."node_modules/@openchamber/web".version;
in
{
  warnings = lib.optionals (openchamberCaskVersion != openchamberServerVersion) [
    ''
      openchamber: desktop cask ${openchamberCaskVersion} does not match the packaged server
      @openchamber/web ${openchamberServerVersion}. The desktop is a client of the server, so bump
      packages/openchamber to the cask version (npm install --save-exact
      @openchamber/web@${openchamberCaskVersion}, then refresh npmDepsHash).
    ''
  ];
}
