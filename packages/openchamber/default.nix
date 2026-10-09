# @openchamber/web, the OpenChamber CLI/Web server.
#
# Upstream only publishes this surface to npm (the desktop apps are separate
# signed installers), so we package the published tarball instead of building
# from source. The tarball already contains the compiled frontend (`dist/`) and
# server (`server/`).
#
# To bump: `cd packages/openchamber && npm install @openchamber/web@<version>`,
# then set `npmDepsHash = lib.fakeHash`, rebuild once and paste the reported
# `got:` hash back here.
{
  lib,
  buildNpmPackage,
  nodejs,
}:

let
  # Read the resolved version from the lockfile so the derivation cannot drift
  # from the tree that `npmDepsHash` was computed for.
  lock = builtins.fromJSON (builtins.readFile ./package-lock.json);
  version = lock.packages."node_modules/@openchamber/web".version;
in
buildNpmPackage rec {
  pname = "openchamber";
  inherit version;

  # Only the manifest and lockfile are needed; `node_modules` is populated from
  # the hashed npm cache by buildNpmPackage.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };

  # The published npm tarball already ships the built frontend (`dist/`) and
  # server (`server/`); there is nothing to compile, so we only need to install
  # the pre-resolved dependency tree.
  # NOTE `node-pty` (the terminal backend) ships prebuilt binaries for
  # darwin/linux, so `npm rebuild` needs no C/C++ toolchain.
  dontNpmBuild = true;

  npmDepsHash = "sha256-TnFUkF610ohO7MSDw10fkIh7AVc1BZEfN+GzY3dMPAI=";

  # `@openchamber/web` exposes its CLI as `openchamber`. The root package.json we
  # use for dependency resolution has no `bin`, so link the nested binary
  # ourselves (buildNpmPackage only installs executables declared at the root).
  postInstall = ''
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/openchamber/node_modules/@openchamber/web/bin/cli.js $out/bin/openchamber
    chmod +x $out/bin/openchamber
  '';

  meta = {
    description = "Agentic Development Environment based on the OpenCode AI agent";
    homepage = "https://github.com/openchamber/openchamber";
    license = lib.licenses.mit;
    mainProgram = "openchamber";
    inherit (nodejs.meta) platforms;
  };
}
