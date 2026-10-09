# OpenCode v2, packaged from the published `@opencode/cli` npm platform tarball.
#
# nixpkgs still tracks the v1 GitHub-release line (`pkgs.opencode` is 1.18.x),
# whose server API OpenChamber v2 refuses to talk to. Upstream v2 ships on npm:
# `@opencode/cli` depends on a per-platform package (`@opencode/cli-<os>-<arch>`)
# whose tarball contains the compiled binary at `package/bin/opencode` — the same
# artifact OpenCode's own installer and OpenChamber's desktop packaging fetch:
#   https://github.com/anomalyco/opencode/blob/main/packages/electron/scripts/prepare-opencode-cli.mjs
# So, like packages/openchamber, we package the published artifact rather than
# building the bun/Vite monorepo from source.
#
# To bump: set `version`, refresh every hash with
#   nix store prefetch-file --json --hash-type sha256 <url>
{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "2.0.26";

  # Nix system -> npm platform package suffix. macOS x64 uses the "baseline"
  # build (no AVX2) — the variant upstream's desktop packaging selects.
  # Only provide systems whose tarball hash is recorded below.
  platform =
    {
      aarch64-darwin = "darwin-arm64";
      x86_64-darwin = "darwin-x64-baseline";
    }
    .${stdenv.hostPlatform.system}
      or (throw "opencode v2: unsupported system ${stdenv.hostPlatform.system}");

  # Hashes of the published tarballs (fetchurl, not fetchzip: these are the
  # flat-file hashes of the .tgz, unpacked explicitly below).
  hashes = {
    darwin-arm64 = "sha256-e03cpeY9OKHSrd02gnCEPCOuugCWE9/Q4zhS05uGEHY=";
    darwin-x64-baseline = "sha256-59vxoXQtiqMWsLt3vbec+YgLPBGreV1CDAO0Qk4VVvM=";
  };
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-${platform}/-/cli-${platform}-${version}.tgz";
    hash = hashes.${platform};
  };

  # The npm tarball unpacks to `package/bin/opencode`.
  unpackPhase = ''
    runHook preUnpack
    tar xzf "$src"
    runHook postUnpack
  '';
  sourceRoot = "package";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode "$out/bin/opencode"
    runHook postInstall
  '';

  meta = {
    description = "AI coding agent (v2 CLI)";
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/releases";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # Published prebuilt binary, not built from source here.
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
