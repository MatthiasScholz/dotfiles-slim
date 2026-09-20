# ADR-0004: Secret management via agenix — retire dormant sops-nix plumbing

- **Status**: Accepted
- **Date**: 2026-09-19
- **Deciders**: Matthias (config owner), coding agent
- **Related**: ADR-0003 (AgentsView config sync-back — the trigger for this decision; its "sops-nix instead of agenix" note is superseded by this ADR)

## Context

### Current state: sops-nix is wired but unused

An audit (2026-09-19) of the sops-nix pieces in this repo:

| Piece | State |
|---|---|
| `flake.nix` input `sops-nix` | ✅ declared, resolved in flake.lock |
| sops Home Manager module wiring | ❌ **dead code** — `secrets/encryption.nix` adds `home-manager.sharedModules`, but that file is imported nowhere (a user-level HM module can't set `home-manager.sharedModules` anyway — that option lives at the nix-darwin level) |
| Declared secrets (`sops.secrets`) | ❌ zero — no `sopsFile`, no `sops.defaultSopsFile` anywhere |
| `.sops.yaml` (sops CLI key/creation-rule config) | ❌ missing |
| Encrypted files | only `secrets/test.yaml` — the stock sops scaffold with `example_*` keys, referenced by nothing |
| Age keypair | ✅ exists: `key.txt` (repo root, gitignored, mode 0600); its public key `age1l5kln63qmzn9chkp6ehee4p33y3j6e5a8znsz23g0yq0r20zwd9sehqn0k` matches the recipient in `secrets/test.yaml` |
| Real usage | none — scaffold created 2024-10-01, never carried a secret |

So the stack is plumbing without a single consumer. It predates current
practice, was never activated, and would have to be *bootstrapped* (`.sops.yaml`,
first real `sops.secrets`, key placement) before it could serve anything.

### The trigger

ADR-0003 needs an encrypted-secret mechanism for AgentsView
(`auth_token`, `github_token`) to implement `make import-secrets-agentsview`:
an encrypted file under version control, decrypted to a target path (or
environment) at activation. The question is which stack becomes **the one**
secret mechanism of this repo.

## Decision

**Adopt agenix as the single secret-management stack and remove the dormant
sops-nix plumbing.**

1. **agenix in**: add `github:ryantm/agenix` as a flake input; wire
   `agenix.homeManagerModules.default` into the user's Home Manager config
   (module file: `home/secretmanagement.nix`); install the `agenix` CLI.
2. **sops-nix out**: remove the `sops-nix` flake input, delete
   `secrets/encryption.nix` (never imported) and `secrets/test.yaml`
   (example-only).
3. **Key reuse**: keep the existing age keypair (`key.txt` and its matching
   public key). agenix and sops both use the age format, so the key carries
   over unchanged — only the *management tooling* changes.
4. **Key placement**: the private key moves from the repo root to the
   conventional location and is registered explicitly:
   - `~/.config/sops/age/keys.txt` (the de-facto standard location for the
     age private key, mode 0600, outside the repo),
   - module sets `age.identityPaths = [ "~/.config/sops/age/keys.txt" ]`
     (the agenix HM default only looks at `~/.ssh/id_ed25519` / `id_rsa`).
5. **Secret file layout**: `secrets/*.age` files encrypted for the repo's
   age recipient (via `.agenixrc` or the `agenix -e` default), decrypted by
   the HM module into `~/.agenix/<name>` (default) or custom `age.secrets.<n>.path`.
6. ADR-0003's `import-secrets-agentsview` target is now implemented as
   `agenix -e secrets/agentsview.age` — an editor flow on the encrypted
   file, not a bespoke YAML-writer.

### Why agenix over the alternatives

- **vs. finishing sops-nix**: both are age-based, but sops-nix here is a
  scaffold that never ran; agenix is dramatically simpler (no `.sops.yaml`,
  no MAC metadata, no key groups) — an `.age` file per secret and
  `age.secrets.<name>.file` in Nix. For a single-user, single-machine
  dotfiles repo, the simpler mental model wins.
- **vs. 1Password (see below)**: 1Password is excellent for *interactive* and
  *ad-hoc* secret retrieval, but it cannot provide the "encrypted blob under
  version control, decrypted at activation by Nix" contract without glue
  that reimplements agenix badly (see Alternatives).

## 1Password approach (evaluated, kept as complementary)

The repo already installs `_1password-cli` (`home/secretmanagement.nix`), so
a 1Password-only flow was seriously considered:

- **Shape**: secrets live in the 1Password vault; no encrypted files in VCS
  at all. Nix references them *by path*, and consumption happens at runtime:
  `AGENTSVIEW_AUTH_TOKEN = "$(op read op://Private/agentsview/token)"` in a
  shell wrapper / `home.sessionVariables`-adjacent wrapper script, or
  sops/agenix replaced by an activation hook that pulls secrets via `op
  read`.
- **Why not primary**:
  - Not declarative at evaluation time: the flake can only reference a
    secret by path; nothing in the flake proves the secret exists or pins
    its value — reproducibility degrades to "as long as 1Password agrees".
  - Runtime coupling: every consumer needs an unlocked 1Password app/agent
    (`op` daemon, biometric unlock) — fine for humans, hostile for
    launchd-managed daemons (the AgentsView LaunchAgent of ADR-0003 must
    decrypt without interactive unlock).
  - Secrets are invisible to `nix flake check` and to `git diff` review, the
    exact review flow ADR-0003 is built on.
- **Kept as complementary**: `_1password-cli` stays installed for ad-hoc
  use (interactive shells, CI bootstrap, one-off retrievals). Rule of
  thumb: *launchd-decrypted file secrets → agenix; human-in-the-loop CLI
  retrievals → `op read`*.

## Architecture (after migration)

```text
flake.nix                     agenix input (sops-nix input removed)
home/secretmanagement.nix     agenix HM module + agenix CLI + age.identityPaths
secrets/                      *.age files (agenix -e/-d), committed encrypted
~/.config/sops/age/keys.txt   age private key (moved from repo key.txt; gitignored)
docs/adr/0003                 import-secrets-agentsview → agenix -e
```

Migration steps:

```bash
# 1. Move the key to the standard location (outside the repo)
mkdir -p ~/.config/sops/age
cp key.txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
# (key.txt can then be deleted; it stays gitignored either way)

# 2. First secret (once ADR-0003 lands)
EDITOR=vim agenix -e secrets/agentsview.age

# 3. Reference in home config
age.secrets."agentsview/auth_token".file = ../secrets/agentsview.age;
```

## Consequences

### Positive

- One secret stack instead of one dormant + one new; no parallel mechanisms.
- agenix's model fits this repo: plain `age` encryption, secrets referenced
  as plain Nix paths, decryption to generation-symlinked paths at activation,
  zero runtime dependencies beyond the key file.
- The existing age keypair carries over — no new trust root, nothing to
  re-encrypt.
- Simpler review story for ADR-0003: `git diff secrets/agentsview.age` shows
  *that* a secret changed (ciphertext diff), the plaintext review happens in
  the `agenix -e` editor step.

### Negative

- No re-encryption of `test.yaml` content — it is deleted outright (it held
  only example keys; if any value in it mattered it never had a consumer).
- agenix has no native "secret in environment variable" mode for HM (sops
  templates did); consumers read decrypted files (`~/.agenix/<name>`) and
  wrap them into env vars with small activation glue — slightly more
  plumbing per secret.
- `.age` files are opaque in diffs; mistakes in an edit are only visible
  after decrypting.

### Risks

- **Key file handling**: the single age key becomes the root of trust for
  all future secrets. It must stay out of VCS (already gitignored), keep
  mode 0600, and be backed up outside this repo (1Password secure note is a
  natural home for the private key — the two stacks complement here).
- Dead references: removing the flake input while something still imports
  `inputs.sops-nix` would break evaluation — the removal is verified by
  `nix flake check` (grep confirms only `secrets/encryption.nix` referenced
  it, and that file is deleted with the input).

## Alternatives considered (and rejected)

| Alternative | Reason rejected |
|---|---|
| Bootstrap the dormant sops-nix stack (add `.sops.yaml`, real secret file) | Works, but maintains two age-secret stacks in the ecosystem for no benefit; sops' flexibility (key groups, KMS, multiple recipients) is unused in a single-user repo |
| 1Password as primary secret store | See dedicated section: runtime coupling to an unlocked 1Password app, no ciphertext in VCS, no reviewable diff — rejected as *primary*, kept for ad-hoc `op read` usage |
| Plain gitignored env-file (`secrets/agentsview.env` untracked) | Works with zero tooling but the file is invisible to the flake (untracked = not in flake source) and is one `git add -f` away from leaking into history |
| `pass`/password-store | Another stack to install and learn; no HM integration story comparable to agenix's `age.secrets` |
| Keep sops-nix *and* agenix | Worst option: two key files, two mental models, two CLIs |

## References

- agenix: <https://github.com/ryantm/agenix> (HM module:
  `homeManagerModules.{age,default}`; CLI: `packages.<system>.agenix`;
  HM identity default `~/.ssh/id_ed25519|id_rsa`, secrets dir `~/.agenix`)
- age: <https://github.com/FiloSottile/age>
- 1Password CLI (`op`): <https://developer.1password.com/docs/cli/>
- sops-nix (retired): <https://github.com/Mic92/sops-nix>
- ADR-0003 — AgentsView sync-back (the consumer of this decision)
- Current wiring before removal: `flake.nix` (input), `secrets/encryption.nix`
  (dead), `home/secretmanagement.nix` (1Password CLI)
