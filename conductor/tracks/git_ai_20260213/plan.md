# Plan: Integrate git-ai as a configurable Nix module

This track integrates `git-ai` as a configurable module in the system flake.

## Phase 1: Preparation & Configuration

- [ ] Task: Create `modules/git-ai.nix` structure
    - **Goal:** Define the Nix module skeleton with `enable` option.
    - **Files:** `modules/git-ai.nix`
    - **Step 1:** Create `modules/git-ai.nix`.
    - **Step 2:** Define `options.modules.git-ai.enable = lib.mkEnableOption "git-ai integration";`.
    - **Step 3:** Add basic `config = lib.mkIf cfg.enable { ... };` block.
    - **Step 4:** Verify `nix flake check` passes (module is valid but does nothing yet).

- [ ] Task: Add git-ai flake input
    - **Goal:** Add `github:git-ai-project/git-ai` to `flake.nix` inputs.
    - **Files:** `flake.nix`
    - **Step 1:** Add input: `git-ai.url = "github:git-ai-project/git-ai";`.
    - **Step 2:** Pass input to `outputs` function.
    - **Step 3:** Update `flake.lock` (`nix flake update git-ai` or `nix flake lock --update-input git-ai`).
    - **Step 4:** Verify `nix flake check` passes.

## Phase 2: Implementation

- [ ] Task: Implement git-ai module logic
    - **Goal:** Install `git-ai` package and configure environment when enabled.
    - **Files:** `modules/git-ai.nix`
    - **Step 1:** Import `git-ai` flake input in module (via `specialArgs` or similar mechanism if needed, or by passing it down). *Correction:* Best practice is to pass `inputs` via `specialArgs` in `flake.nix`.
    - **Step 2:** In `config`, add `git-ai.packages.${pkgs.system}.default` (or specific package name) to `home.packages` or `environment.systemPackages`.
    - **Step 3:** Configure any necessary shell hooks/aliases (e.g., `programs.zsh.initExtra` or `home.sessionVariables`).
    - **Step 4:** Verify `nix flake check` passes.

- [ ] Task: Expose and Enable git-ai module
    - **Goal:** Import the module in `darwin/darwin.nix` (or `home/home.nix`) and enable it for the user.
    - **Files:** `darwin/darwin.nix`, `home/home.nix` (depending on where modules are imported), `flake.nix`.
    - **Step 1:** Add `./modules/git-ai.nix` to `modules` list in `flake.nix` (for `darwinConfigurations`) or `home-manager` users config.
    - **Step 2:** Set `modules.git-ai.enable = true;` in the appropriate configuration file (e.g., `darwin/darwin.nix` or `home/home.nix`).
    - **Step 3:** Verify configuration builds (`nix build .#darwinConfigurations.<hostname>.system` --dry-run).

## Phase 3: Verification

- [ ] Task: Verify Installation
    - **Goal:** Ensure `git-ai` command is available.
    - **Step 1:** Run `nix run nix-darwin -- switch --flake .` (if safe/desired, or user manual check).
    - **Step 2:** Check `which git-ai`.
    - **Step 3:** Check `git ai --version`.

- [ ] Task: Conductor - User Manual Verification 'Implementation' (Protocol in workflow.md)
