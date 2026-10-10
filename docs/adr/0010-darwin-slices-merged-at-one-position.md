# ADR-0010: System surface split into one-concern slices merged at one position

- **Status**: Accepted
- **Date**: 2026-10-10
- **Deciders**: Matthias (config owner), coding agent
- **Related**: ADR-0002 (kanata root daemon + tray lifecycle twin), ADR-0006
  (stable code-signed kanata copy), ADR-0007 (Nix settings under `/etc/nix`),
  ADR-0008 (OpenChamber desktop client) — all now implemented in slices;
  homeserver-nix ADR 025 (remote builders), implemented in
  `darwin/remote-builders.nix`.

## Context

The system surface (everything nix-darwin evaluates for a machine) used to be
one file, `darwin/darwin.nix`. It grew to 809 lines and became the repo's
hottest file (16 of the last 60 commits). Kanata's tray lifecycle and TCC
signing sat next to the homebrew cask list and the Nix daemon settings, so a
change to one concern meant reading and re-verifying the others.

## Decision

Split the system surface into one-concern slices under `darwin/`:
`nix.nix`, `remote-builders.nix`, `openchamber.nix`, `homebrew.nix`,
`system.nix`, `slack.nix`, `kanata.nix`. `darwin/default.nix` aggregates them.

The aggregator **merges the slices at its own module position** with
`lib.mkMerge` over `import`ed slice modules. It must **not** use an
`imports = [ ... ]` list.

## Why not `imports`

The Nix module system orders imported modules *after* the importing module's
siblings. With the slices pulled in via `imports`, their definitions landed
after Home Manager's and the determinate module's, which reordered:

- **`types.lines` options**, concatenated in definition order — so the
  generated activation scripts (`postActivation`, `extraActivation`, and the
  aggregated `script`) changed; and
- **list options merged by concatenation** — `environment.systemPackages`
  changed order (Home Manager's entry moved from the end to the front).

Both are observable: the system derivation changed even though no value was
edited. `lib.mkMerge` keeps every slice definition at `default.nix`'s
position, so the split is byte-for-byte behaviour-identical — verified against
`darwinConfigurations.<host>.system.drvPath` and the captured option values on
the aarch64 profile, with the MacPro (x86_64) option values identical too.

## Alternatives considered

- **`imports = [ ... ]`** — idiomatic, and the obvious way to compose modules.
  Rejected: it changes activation-script and `systemPackages` ordering, and so
  the system derivation (see above).
- **List the slices directly in `flake.nix`'s `modules` list** — order
  preserving (verified), but leaks the slice inventory into the flake and
  abandons the `darwin/default.nix` seam.
- **Keep the single god module** — rejected: no locality; every change reads
  the whole file.

## Consequences

- A change touches one slice; the file name names the concern.
- Adding a slice is a one-line edit in `darwin/default.nix`, which also
  forwards the module args the slices receive (`config`, `lib`, `pkgs`).
  Unlike `imports`, the module system does not hand args to the slices
  automatically, so a slice that needs a new arg (e.g. `inputs`) must have it
  added here.
- **Do not "simplify" `darwin/default.nix` to `imports`.** Per this decision it
  silently changes activation ordering and the system derivation. The header
  comment in `darwin/default.nix` repeats the warning.
- The decorative separator comment that followed the `environment.etc` block in
  the old file was dropped in the move (comment only, no content).

## References

- Split commit: `♻ refactor(darwin): split the god module into cohesive slices`
- Review: architecture review candidate #3 ("Split the darwin god module")
