# Secret management
#
# agenix is the single secret stack of this repo (docs/adr/0004-secrets-via-agenix.md).
# The dormant sops-nix scaffold (flake input, secrets/encryption.nix,
# secrets/test.yaml) was removed — see ADR-0004.
#
# Usage:
#   agenix -e secrets/<name>.age         # create/edit a secret (age-encrypted)
#   age.secrets.<name>.file = ../secrets/<name>.age;
#
# The age private key lives at ~/.config/sops/age/keys.txt (moved from the
# repo-root key.txt of the retired sops scaffold; mode 0600, never committed).
# 1Password CLI stays installed for ad-hoc, human-in-the-loop retrievals
# (`op read`) — agenix for launchd-decrypted file secrets, `op` for interactive ones.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  # Provides the `age.secrets.*` options for the user's Home Manager config
  imports = [
    inputs.agenix.homeManagerModules.default
  ];

  # The agenix HM default identities are ~/.ssh/id_ed25519|id_rsa; register
  # the conventional sops/age key location instead.
  age.identityPaths = [ "${config.home.homeDirectory}/.config/sops/age/keys.txt" ];

  home.packages = [
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
    pkgs._1password-cli
    # TODO marked as broken
    # _1password-gui
  ];
}
