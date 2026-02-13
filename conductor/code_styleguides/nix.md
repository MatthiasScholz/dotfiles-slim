# Nix Style Guide

## General
- **Indentation:** 2 spaces.
- **Line Length:** Try to keep lines under 100 characters.
- **Comments:** Use `#` for single-line comments. Explain *why*, not *what*.

## Formatting
- Use `nixfmt` (or `alejandra`) for consistent formatting.
- Align attribute sets vertically where readable.

## Naming
- **Files:** `camelCase` or `kebab-case` (consistent within directory).
- **Variables:** `camelCase`.
- **Options:** `camelCase` (e.g., `enableGitAi`, `extraPackages`).

## Structure
- Use `let ... in` for local bindings.
- Group related options together.
- Use `lib.mkIf` for conditional activation.
