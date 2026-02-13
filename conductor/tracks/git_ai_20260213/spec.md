# Track: Integrate git-ai as a configurable Nix module to track AI contributions

## Context
The goal is to integrate `git-ai` (a tool for tracking AI-generated code) into the existing Nix-managed dotfiles repository. This will allow tracking AI contributions across the system. The module must be configurable (enable/disable) via Nix options.

## Requirements

### Functional
1.  **Add Flake Input:** Include `github:git-ai-project/git-ai` as a flake input.
2.  **Create Nix Module:** Implement `modules/git-ai.nix` (or similar).
3.  **Configurability:** The module must expose an option (e.g., `modules.git-ai.enable`) to toggle activation.
4.  **Overlay:** Use a Nix overlay to make `git-ai` available and wrap `git` to use it.
5.  **Installation:** Ensure `git-ai` is installed in the user environment when enabled.
6.  **Hook Integration:** Verify necessary hooks or environment variables are set (likely for Zsh/Bash).

### Non-Functional
1.  **Strictly Declarative:** Managed entirely via Nix.
2.  **Code Style:** Follow project conventions (2 spaces, camelCase).
3.  **Testing:** Verify `nix flake check` passes after implementation.

## Proposed Implementation

1.  **Update `flake.nix`:** Add `git-ai` to inputs.
2.  **Create `modules/git-ai.nix`:**
    -   Define options: `options.modules.git-ai.enable = lib.mkEnableOption "git-ai integration";`
    -   Configure implementation: `config = lib.mkIf cfg.enable { ... }`
    -   Apply overlay to `nixpkgs` instance.
    -   Add `git-ai` to `home.packages`.
    -   Configure shell integration (if required by `git-ai`).
3.  **Update `darwin/darwin.nix` / `home/home.nix`:** Import the new module and enable it.

## Verification Plan

### Automated
-   Run `nix flake check`.
-   Run `nix build .#darwinConfigurations.<hostname>.system` (dry run or check build).

### Manual
-   Enable the module.
-   Run `git ai --version` to verify installation.
-   Check `git` integration (e.g., `git ai status` or simply `git status` to see if hooks fire).
