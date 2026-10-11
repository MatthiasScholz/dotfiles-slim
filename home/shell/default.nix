# Home shell surface, split into cohesive slices.
#
# This was formerly one `shell.nix` god module that owned every shell concern: a
# pinned warp-terminal derivation and the shell package list, global aliases and
# session variables, the CLI-replacement tools, the starship prompt, the whole
# zsh configuration and its emacs-vterm integration. Each slice now owns one
# concern and is merged here; Home Manager sees the result as one module.
#
# Slice map:
#   env.nix    home.shellAliases, sessionVariables, sessionPath
#   tools.nix  pinned warp-terminal + home.packages, eza/bat/atuin/zoxide/ripgrep
#   prompt.nix programs.starship
#   zsh.nix    programs.zsh (except initContent) + programs.bash
#   vterm.nix  programs.zsh.initContent: emacs-vterm integration
#
# NOTE: deliberately *not* an `imports = [ ... ]` list. Imported modules are
# ordered after the importing module's siblings, which reorders `types.lines`
# (zsh initContent, activation scripts) and list options (home.packages,
# home.sessionPath) relative to Home Manager's own modules, changing the
# activation generation. Merging at this module's own position keeps the split
# byte-for-byte behaviour-identical (ADR-0010), verified against the Home
# Manager generation.
{ config, lib, pkgs, ... }:

lib.mkMerge [
  (import ./env.nix { inherit config lib pkgs; })
  (import ./tools.nix { inherit config lib pkgs; })
  (import ./prompt.nix { inherit config lib pkgs; })
  (import ./zsh.nix { inherit config lib pkgs; })
  (import ./vterm.nix { inherit config lib pkgs; })
]
