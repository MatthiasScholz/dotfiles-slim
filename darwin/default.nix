# System surface (nix-darwin), split into cohesive slices.
#
# This was formerly one `darwin.nix` god module that owned the whole system, so a
# kanata change and a homebrew change lived in the same file. Each slice now owns
# one concern and is merged here; nix-darwin sees the result as one module.
#
# Slice map:
#   nix.nix             /etc/nix/nix.custom.conf, the nix daemon settings (ADR-0007)
#   remote-builders.nix remote-builder SSH hosts + /etc/nix/machines (ADR 025)
#   openchamber.nix     cask<->server version-sync warning (ADR-0008)
#   homebrew.nix        taps, brews, casks, masApps
#   system.nix          packages, programs, fonts, services, pam, system.defaults
#   slack.nix           disable Slack auto-update via managed preferences
#   kanata.nix          kanata/karabiner daemons, tray shim, TCC stable copy (ADR-0002/0006)
#
# NOTE: deliberately *not* an `imports = [ ... ]` list. Imported modules are
# ordered after the importing module's siblings, which reorders `types.lines`
# (activation scripts) and list options (systemPackages) relative to Home Manager
# and the determinate module, changing the activation script and the system
# derivation. Merging here keeps every definition at this module's position, so
# the split is byte-for-byte behaviour-identical (verified against the system
# derivation hash).
{ config, lib, pkgs, ... }:

lib.mkMerge [
  (import ./nix.nix { inherit config lib pkgs; })
  (import ./remote-builders.nix { inherit config lib pkgs; })
  (import ./openchamber.nix { inherit config lib pkgs; })
  (import ./homebrew.nix { inherit config lib pkgs; })
  (import ./system.nix { inherit config lib pkgs; })
  (import ./slack.nix { inherit config lib pkgs; })
  (import ./kanata.nix { inherit config lib pkgs; })
]
