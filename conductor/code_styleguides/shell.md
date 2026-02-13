# Shell Style Guide

## General
- **Indentation:** 2 spaces.
- **Shebang:** `#!/usr/bin/env bash` or `#!/usr/bin/env zsh`.

## Conventions
- Use explicit `local` for variables in functions.
- Quote variables (`"$var"`) to prevent word splitting.
- Use `set -e` (or equivalent) for fail-fast scripts.

## Error Handling
- Check exit codes (`if ! command; then ...`).
- Use `trap` for cleanup.

## Formatting
- Use `shfmt` for consistent style.
