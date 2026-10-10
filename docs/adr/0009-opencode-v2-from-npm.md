# ADR-0009: OpenCode v2 sourced from the npm `@opencode/cli` artifact

- **Status**: Accepted
- **Date**: 2026-10-08
- **Deciders**: Matthias (config owner), coding agent
- **Related**: ADR-0005 (packaged `@openchamber/web` from npm for the same
  reason), ADR-0008 (desktop app is a client of the module server, which talks
  to this OpenCode), ADR-0001 (imperative installers are converted, not
  executed), ADR-0011 (the attach contract owns the OpenCode-side password
  shim)

## Context

OpenChamber v2 (`@openchamber/web`, the `programs.openchamber` server) speaks
the **OpenCode v2** server API. ADR-0008 wired the desktop app and the module
server to a single OpenCode instance — the one `programs.opencode.web` already
runs on `:4096` — but that instance was **v1**:

- `programs.opencode.package` defaulted to nixpkgs `pkgs.opencode`, which
  unstable still pins to `1.18.33` (`pkgs/by-name/op/opencode/package.nix`);
  nixpkgs has no v2 package (`opencode-desktop` builds from the same v1 source).
- The installed `opencode` reported `1.18.33`, and `OPENCODE_BINARY` pointed at
  it. OpenChamber therefore attached to a v1 server it does not support.

Upstream ships v2 differently from v1. v1 was GitHub release zips
(`anomalyco/opencode`). **v2 is published to npm**: the meta package
`@opencode/cli` depends on a per-platform `@opencode/cli-<os>-<arch>` whose
tarball contains the compiled binary at `package/bin/opencode`. OpenCode's own
installer (`https://opencode.ai/v2/install`) and OpenChamber's desktop build
(`packages/electron/scripts/prepare-opencode-cli.mjs`) both fetch exactly these
tarballs. The binary is a self-contained Mach-O that links only against
`/usr/lib` system libraries.

This is the same situation ADR-0005 faced for `@openchamber/web`: the upstream
artifact is already built, and packaging it is cheap and reproducible.

## Decision

**Package the published `@opencode/cli` v2 platform tarball as a Nix
derivation and make it the OpenCode used by `programs.opencode`.**

1. **`packages/opencode/default.nix`** — a `fetchurl`-based derivation that
   downloads the per-arch npm tarball, unpacks it explicitly (`package/bin/opencode`),
   and installs `bin/opencode`. Version `2.0.26`; per-arch hashes recorded for
   `aarch64-darwin` (`darwin-arm64`) and `x86_64-darwin`
   (`darwin-x64-baseline`), mirroring upstream's own desktop arch mapping.
   `meta.mainProgram = "opencode"`; `sourceProvenance = binaryNativeCode`.
2. **Override the package.** `home/agentic.nix` sets
   `programs.opencode.package = pkgs.callPackage ../packages/opencode { }`, so
   the Home Manager module's CLI, its `web` service on `:4096`, and
   `programs.openchamber`'s `OPENCODE_BINARY` all resolve to v2.
3. **Drop the v1-only flag.** `programs.opencode.web.extraArgs` loses
   `--mdns`: v2 `serve` accepts `--hostname`/`--port`/`--cors`/`--stdio` but not
   `--mdns` (LAN/mDNS discovery moved under the `service` subsystem).
4. **Assume config compatibility, verified.** v2 reads the same
   `~/.config/opencode/opencode.json` (and `tui.json`); running
   `opencode debug config` on the v2 binary against the existing config listed
   the same plugin and MCP entries, and mapped `autoupdate=false` to
   `update=disable`. No config rewrite was required.
5. **Server password via agenix.** v2 requires HTTP Basic auth on `/api/*`
   (`GET /api/info` is `401` without it, even on loopback). The
   `programs.opencode.web` service gets `OPENCODE_SERVER_PASSWORD` from
   `secrets/opencode-server.age` through Home Manager's `web.environmentFile`
   (sourced by the launchd wrapper), and the OpenChamber server reads the same
   secret through `programs.openchamber.attach.serverPasswordFile`, so its
   external compatibility probe (`readExternalOpenCodeVersion` → `GET /api/info`
   with `Authorization: Basic opencode:<pw>`) authenticates and reads the
   version. The wait shim behind `web.environmentFile` is owned by that attach
   option, not wired by hand (ADR-0011).

A bump is: set `version`, refresh each hash with
`nix store prefetch-file --json --hash-type sha256 <url>`.

## Consequences

### Positive

- **OpenChamber works.** The server and the desktop client talk to a v2 OpenCode
  API.
- **One agent runtime.** CLI, `web` service, OpenChamber server and the desktop
  client all use the same v2 binary and the same `:4096` instance.
- **Pinned and reproducible.** The version is in Nix, hashes in git; no global
  installer, no `opencode upgrade`.
- **No build toolchain.** The tarball is a prebuilt binary; Nix re-signs it
  ad-hoc on `aarch64-darwin` (verified: it runs from the store).

### Negative

- **Hand-maintained per-arch hashes.** Two hashes today (darwin arm64 / x64);
  a bump touches the version plus every hash. Linux is not wired yet.
- **Tracks npm, not nixpkgs.** If/when nixpkgs ships v2, this derivation should
  be deleted in favour of `pkgs.opencode`.
- **Plugin compatibility is not guaranteed.** `modules/opencode-plugin-versions.nix`
  was pinned against v1. v2 parsed the same plugin list, but each plugin's
  runtime compatibility with the v2 API must be confirmed separately (e.g.
  `opencode-notifier`, `@ramtinj95/opencode-tokenscope`).
- **v2 CLI surface differs.** `service` is new; `serve` lost `--mdns`. Anything
  scripted against v1 flags can break (`nix flake check` cannot catch this).

### Risks

- **Login-order race.** Both services read the agenix secret at launchd start;
  agenix decrypts it from its own LaunchAgent. Both now wait (bounded, 60 s)
  for the file — OpenChamber in its launchd wrapper, OpenCode via a generated
  `environmentFile` shim, because Home Manager's darwin wrapper only `source`s
  the file and would otherwise start the v2 server without a password. NOTE a
  `make switch` that does not change the plist will not restart the service, so
  a stale passwordless process can survive a switch; restart it with
  `launchctl kickstart -k gui/$(id -u)/org.nix-community.home.opencode-web` if
  `GET /api/info` still returns `401`.
- **One password, two surfaces.** The OpenCode server password is a shared
  credential; rotating it means re-encrypting `secrets/opencode-server.age`
  and switching.
- **`darwin-x64-baseline` on the Intel MacPro** disables AVX2; a newer Xeon
  could use the non-baseline build for speed, but baseline is the safe default.
  Switch the suffix if profiling justifies it.
- **Upstream npm layout.** The `@opencode/cli-<os>-<arch>` naming and
  `package/bin/opencode` path are implementation details; a future release can
  change them and break the fetch (loudly, at build time).

## Alternatives considered (and rejected)

| Alternative | Reason rejected |
|---|---|
| Wait for nixpkgs to package OpenCode v2 | No ETA; blocks OpenChamber indefinitely |
| Build OpenCode v2 from source (bun monorepo) | Heavy (bun + Vite + native rebuilds), and nixpkgs already shows the prebuilt artifact is the cheaper path; the published binary is exactly what upstream ships |
| Point OpenChamber at the desktop app's bundled OpenCode | ADR-0008 runs the desktop in client mode, where it starts no OpenCode; the module server still needs its own v2 |
| Let OpenChamber supervise its own OpenCode instead of `programs.opencode.web` | Keeps a second OpenCode/version next to `programs.opencode`; contradicts ADR-0008's single-runtime design and splits config |
| `opencode upgrade` / `curl … opencode.ai/v2/install \| bash` | Imperative, unpinned, mutates a global prefix outside Nix — ADR-0001 |

## References

- Package: `packages/opencode/default.nix`; override: `home/agentic.nix`
- npm: <https://www.npmjs.com/package/@opencode/cli>
- Upstream desktop packaging (arch mapping / artifact URL):
  `packages/electron/scripts/prepare-opencode-cli.mjs` in
  <https://github.com/anomalyco/opencode>
- OpenCode v2 install docs: <https://opencode.ai/v2>
- nixpkgs v1 package: `pkgs/by-name/op/opencode/package.nix`
- Related: ADR-0001, ADR-0005, ADR-0008
