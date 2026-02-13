# Plan: Integrate git-ai with priority-based wrapper

## Phase 1: Core Module Enhancement & Loop Prevention
- [x] Task: Modify `modules/git-ai.nix` to implement priority logic
    - Use `lib.hiPrio` for `inputs.git-ai.packages.${pkgs.system}.default`.
    - **Loop Prevention**: Hardcode `git_path` in `.git-ai/config.json` to `${pkgs.git}/bin/git`. 
    - This ensures `git-ai` calls the real binary directly, even when `git` is aliased to `git-ai`.
    - Uncomment and fix Zsh completion (`compdef git-ai=git`).
- [x] Task: Update `home/git.nix`
    - Set `modules.git-ai.enable = true`.
    - Wrap `programs.git.package` with `lib.lowPrio` to ensure the standard package doesn't collide with the wrapper.
- [x] Task: Add Nix-based safety assertions
    - Add `assertions` to the `git-ai.nix` module to verify that `pkgs.git` is available.

## Phase 2: Configuration & Integration
- [x] Task: Verify the `git_path` in `modules/git-ai.nix`
    - Verify that the path resolved by `${pkgs.git}/bin/git` is the actual binary and not another wrapper.
- [x] Task: Synchronize git user settings
    - Ensure `git-ai` can read the user identity (`settings.user.name`) configured in `home/git.nix`.

## Phase 3: Verification
- [x] Task: Run `make check` to verify flake validity.
- [ ] Task: Conductor - User Manual Verification 'git-ai binary check' (Protocol in workflow.md)
    - Run `which git` and verify it's the wrapper.
    - Run `git ai prompts` to check database access.
    - **Recursion Test**: Run `git version` to ensure it returns the standard git version without looping.

## Phase 4: Activation Fix
- [x] Task: Fix `home-manager.backupFileExtension` placement in `flake.nix`
    - Move it from flake outputs to the `home-manager` configuration block in `darwinConfigurations`.
- [ ] Task: Verify activation
    - Ensure `make setup` can now proceed by automatically backing up the existing config.
