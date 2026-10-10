# Agentic surface (Home Manager), split into cohesive slices.
#
# This was formerly one `agentic.nix` god module that owned the whole agentic
# stack: MCP servers, the OpenCode core and its web service, the ocx registry,
# the oh-my-opencode-slim profile, the agentic CLI package list, AgentsView and
# OpenChamber. A change to one concern read and re-verified the rest. Each slice
# now owns one concern and is merged here; Home Manager sees the result as one
# module.
#
# Slice map:
#   mcp.nix                 programs.mcp servers (shared with OpenCode)
#   opencode.nix            programs.opencode + pinned plugin versions
#   ocx.nix                 programs.ocx enable flag + the xdg ocx.jsonc registry
#   oh-my-opencode-slim.nix programs.oh-my-opencode-slim profile
#   packages.nix            home.packages: agentic CLIs + pi-acp
#   agentsview.nix          programs.agentsview
#   openchamber.nix         age.secrets + programs.openchamber (attach + desktop)
#
# Merge order mirrors the old file (mcp, opencode, ocx, oh-my-opencode-slim,
# packages, agentsview, openchamber).
#
# NOTE: deliberately *not* an `imports = [ ... ]` list for the slices. Imported
# modules are ordered after the importing module's siblings, which reorders
# `types.lines` (activation scripts) and list options (home.packages,
# xdg.configFile) relative to Home Manager's own modules, changing the
# activation generation. Merging at this module's own position keeps the split
# byte-for-byte behaviour-identical (ADR-0010), verified against the Home
# Manager generation and the nix-darwin toplevel.
#
# The three `modules/` imports below stay on this module's `imports`: they are
# real modules that declare options, and `imports` is not special-cased inside a
# `lib.mkMerge` element, so they cannot move into the slices. Keeping them
# imported here preserves the old definition order exactly — this aggregator
# holds the same module position `agentic.nix` did.
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/ocx-module.nix
    ../../modules/oh-my-opencode-slim.nix
    ../../modules/openchamber.nix
  ];

  config = lib.mkMerge [
    (import ./mcp.nix { inherit config lib pkgs; })
    (import ./opencode.nix { inherit config lib pkgs; })
    (import ./ocx.nix { inherit config lib pkgs; })
    (import ./oh-my-opencode-slim.nix { inherit config lib pkgs; })
    (import ./packages.nix { inherit config lib pkgs; })
    (import ./agentsview.nix { inherit config lib pkgs; })
    (import ./openchamber.nix { inherit config lib pkgs; })
  ];
}
