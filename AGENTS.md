# Agent Instructions

This document provides guidelines for AI agents working in this repository.

## 1. Build, Lint, and Test Commands

This project is a **NixOS/Darwin dotfiles** repository using **Flakes**.

### Primary Commands
- **Check Validity**: Run this to verify the flake code syntax and validity.
  ```bash
  make check
  # OR
  nix flake check
  ```
- **Deploy/Switch (Darwin)**: Apply the configuration to the current macOS system.
  ```bash
  make setup
  # OR
  sudo nix run nix-darwin -- switch --flake . --refresh
  ```
- **Update Dependencies**: Update flake inputs.
  ```bash
  make update
  # OR
  nix flake update
  ```
- **Show Flake Info**:
  ```bash
  make info
  ```

### Linting & Formatting
- **Nix**: Use standard Nix formatting (2 spaces indentation).
- **Lua**: Use standard Lua formatting (2 spaces indentation).
- **Linting**: Rely on `nix flake check` to catch basic errors.

### Testing
There is no granular unit test suite for individual functions.
- **Single Source of Truth**: `flake.nix` is the entry point.
- **Validation**: The primary "test" is `nix flake check`. If this passes, the configuration is syntactically valid.

---

## 2. Code Style & Conventions

### General
- **Indentation**: 2 spaces for all files (`.nix`, `.lua`, `.json`, `.yaml`).
- **Line Length**: Prefer lines under 100 characters where possible.
- **Comments**:
  - Use `#` for comments in Nix and Shell.
  - Use `--` for comments in Lua.
  - Use `TODO` and `FIXME` to mark areas for improvement or known issues.
  - Explain *why* a complex configuration exists, not just *what* it is.

### Nix (`.nix`)
- **Structure**:
  - `flake.nix`: Entry point. Defines inputs and outputs.
  - `darwin/`: System-level macOS configuration (nix-darwin).
  - `home/`: User-level configuration (Home Manager).
  - `config/`: Application-specific config files (often symlinked or read by nix).
- **Syntax**:
  - Use `let ... in` blocks for local variables.
  - Prefer multi-line lists for `packages` and `modules`.
  - Use `lib.mkIf` for conditional configuration (e.g., `pkgs.stdenv.isDarwin`).
- **Naming**:
  - Use **camelCase** for variable names (e.g., `nixpkgsConfig`, `useGlobalPkgs`).
  - Filenames should be lowercase and descriptive (e.g., `home.nix`, `wezterm.nix`).

### Lua (Hammerspoon/WezTerm)
- **Globals**: Avoid global variables unless necessary for the specific tool (e.g., Hammerspoon `spoon` global).
- **Modules**: Require modules at the top of the file.

### Error Handling
- **Nix**: Fail early. If a configuration is invalid, `nix flake check` should catch it.
- **Darwin**: Be aware that `darwin-rebuild` requires `sudo`.
- **Backups**: The configuration is set to backup existing files (`home-manager.backupFileExtension = "bak"`). Do not manually delete files unless explicitly instructed.

---

## 3. Workflow Guidelines for Agents

1.  **Analyze First**: Before making changes, understand if the task is for **System** (`darwin/`) or **User** (`home/`) configuration.
2.  **Verify**: Always run `make check` after modifying any `.nix` file.
3.  **Dependencies**: Check `flake.nix` inputs before adding new dependencies.
4.  **Idempotency**: Nix configurations should be declarative and idempotent. Avoid writing imperative scripts if a declarative Nix option exists.
5.  **Platform**: Assume the environment is **macOS (Darwin)** unless specified otherwise.
6.  **Safety**:
    - Do not commit secrets.
    - Check for `secrets/` directory or `sops-nix` usage before touching sensitive configs.
    - Do not run `make setup` (deploy) unless explicitly asked by the user, as it modifies the live system.

---

## 4. Cursor / Copilot Rules
*(No specific Cursor or Copilot rules found in the repository at this time.)*
