# ADR-0011: `programs.openchamber` owns the OpenChamber → OpenCode attach contract

- **Status**: Accepted
- **Date**: 2026-10-10
- **Deciders**: Matthias (config owner), coding agent
- **Related**: ADR-0005 (module + declarative LaunchAgent), ADR-0008 (the
  desktop client is a *different* attach), ADR-0009 (shared
  `OPENCODE_SERVER_PASSWORD` + the login-order race), ADR-0004 (secret file
  paths only)

## Context

OpenChamber can either supervise its own OpenCode server or **attach** to one
that already runs, using `OPENCODE_HOST` + `OPENCODE_SKIP_START` and the shared
`OPENCODE_SERVER_PASSWORD` (ADR-0009). That contract was split across two
files:

- `modules/openchamber.nix` owned `opencodePasswordFile` (the LaunchAgent
  wrapper sourced it) and the env plumbing;
- `home/agentic.nix` set `OPENCODE_HOST` / `OPENCODE_SKIP_START` and built the
  **OpenCode-side** `environmentFile` shim by hand with
  `launchdLib.mkSecretEnvFile`.

So the module was only complete if the caller knew to set three things **and**
re-derive the shim, and the same `opencode-server` secret was wired twice. An
architecture review flagged it (candidate #5: move the wiring behind the module
seam).

The tension is real: one side of the contract configures `programs.openchamber`,
the other configures `programs.opencode`. The shim arguably belongs to OpenCode
("OpenCode needs a password because someone attaches to it"); but whoever
*requires* the password is the attach.

## Decision

**`programs.openchamber.attach` owns the whole contract.**

```nix
programs.openchamber.attach = {
  enable = true;
  host = "http://localhost:4096";               # → OPENCODE_HOST
  serverPasswordFile = config.age.secrets."opencode-server".path;
};
```

When `attach.enable`:

1. the module sets `OPENCODE_HOST = attach.host` and
   `OPENCODE_SKIP_START = "true"` (mirrored into the session and the
   LaunchAgent);
2. the LaunchAgent wrapper sources `serverPasswordFile` (`kind = "source"`,
   as before);
3. when `programs.opencode.web.enable` **and** `serverPasswordFile != null` the
   module sets `programs.opencode.web.environmentFile` to the same bounded-wait
   shim.

`opencodePasswordFile` is renamed to `attach.serverPasswordFile` (one in-repo
caller; no alias). `desktopClient` (ADR-0008) stays a separate option — it
attaches the desktop app to *this* server, the opposite direction.

### Why the module owns the shim

Locality. The module is what requires OpenCode to be passworded, the agenix
race is fixed once, and the caller's interface shrinks to one option. The
cross-program write is deliberate and bounded: it is one Home Manager option,
guarded, and it exists only to satisfy the attach the module itself declared.

### Precedence

- `OPENCODE_HOST` / `OPENCODE_SKIP_START` are reserved for `attach`; an
  assertion rejects them in `environment` while `attach.enable = true`, so a
  stale copy fails `nix flake check` instead of silently winning.
- `programs.opencode.web.environmentFile` is `nullOr path` (single-valued). If a
  caller also sets it, the module merge fails loudly on differing values; there
  is no silent last-wins.

## Consequences

### Positive

- **Locality.** The contract, both secret waits and the agenix race live in
  `modules/openchamber.nix`; `home/agentic.nix` sets one option plus the secret
  path.
- **Leverage.** A second machine or user learns `attach`, not the wiring.
- **Move-only and verified.** For the current caller the LaunchAgent plist, the
  `opencode-server-env` shim store path and `home.sessionVariables` are
  byte-identical to the pre-move configuration.

### Negative

- **Cross-program coupling.** `modules/openchamber.nix` writes
  `programs.opencode.web.environmentFile` and therefore depends on that Home
  Manager option name; a future HM rename breaks the attach (loudly, at
  evaluation).
- **Single-valued slot.** `environmentFile` holds one path, so the module owns
  it exclusively. A second env file for the OpenCode service would have to be
  composed into the shim by hand.
- **Darwin-only in disguise.** The shim is a bash file `source`d by launchd; on
  Linux systemd would parse it as a `KEY=VALUE` `EnvironmentFile` and fail. This
  was already true when the caller built it; the move just hides the assumption
  in the module.

### Risks

- **Guard skips silently when OpenCode is unmanaged.** If `programs.opencode.web`
  is off, no shim is installed — correct for an external OpenCode, but the
  password is then only sourced into the OpenChamber wrapper.
- **`serverPasswordFile = null` is allowed** (a passwordless external server).
  Attaching to a passworded server with a null file yields 401s at runtime,
  which Nix cannot catch.

## Alternatives considered (and rejected)

| Alternative | Reason rejected |
|---|---|
| Keep the shim in `home/agentic.nix`, expose a helper | The seam keeps leaking; the caller still re-derives the contract (the thing candidate #5 exists to fix) |
| Give OpenCode its own `attachPasswordFile` option | Adds a public option to a second module and moves the cross-write, not removes it |
| Publish `mkSecretEnvFile` for both sides to call | Most flexible, least locality; two call sites to keep in sync |
| Fold this into `desktopClient` | Different direction (desktop → OpenChamber vs OpenChamber → OpenCode); ADR-0008 |

## References

- Module: `modules/openchamber.nix` (`attach`, `attachEnvironment`, shim on
  `programs.opencode.web.environmentFile`)
- Caller: `home/agentic.nix`
- Shard secret-env shim: `lib/launchd.nix` (`mkSecretEnvFile`)
- Glossary: `CONTEXT.md` — **OpenCode attach**
- Related: ADR-0004, ADR-0005, ADR-0008, ADR-0009
