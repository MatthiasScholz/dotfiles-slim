# Spec: Comprehensive git-ai Integration with System-Wide Wrapper

## Overview
The goal is to enable `git-ai` system-wide as the primary `git` binary. By using a wrapper approach with Nix priority management, we ensure that AI tracking is active not just in the shell, but also in editors (Emacs, Zed) and scripts, while maintaining access to the underlying standard `git`.

## Functional Requirements
1.  **Enable Module:** Activate the `modules.git-ai` module in `home/git.nix`.
2.  **Priority Management:** 
    - Set the `git-ai` package to `lib.hiPrio` to ensure its `git` binary takes precedence.
    - Set the standard `pkgs.git` to `lib.lowPrio` to resolve collisions while keeping it available for the wrapper.
3.  **Wrapper Configuration:** Configure `.git-ai/config.json` to point `git_path` explicitly to the low-priority standard git binary.
4.  **Shell Integration:** 
    - Enable Zsh aliases (`git = "git-ai"`).
    - Restore and fix Zsh completions so `git-ai` inherits standard git completion logic.
5.  **CLI Access:** Ensure the `git-ai` command itself is directly accessible for meta-operations (prompts analysis, etc.).

## Verification via Nix
1.  **Dry-run Validation:** Ensure `nix flake check` validates the syntax of the new priority logic.
2.  **Assertion Logic:** Add `assertions` within the module to ensure `programs.git.enable` is true if `modules.git-ai.enable` is true.
3.  **Build Verification:** Use `make check` to verify that the configuration builds and that the `git` binary path resolved in the module is valid.

## Acceptance Criteria
1.  `which git` points to the `git-ai` wrapper in the Nix store.
2.  `git --version` and `git ai --version` both return valid output.
3.  `git ai prompts` works correctly to access the local database.
4.  `nix flake check` passes without errors.
