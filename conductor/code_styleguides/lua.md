# Lua Style Guide

## General
- **Indentation:** 2 spaces.
- **Line Length:** Try to keep lines under 100 characters.
- **Comments:** Use `--` for single-line comments.

## Formatting
- Use `lua-format` for consistent formatting.

## Naming
- **Files:** `lowercase` with `.lua` extension.
- **Variables:** `camelCase` for locals, `PascalCase` for classes/modules.
- **Functions:** `camelCase`.

## Modules
- Prefer `local function` over global.
- Explicitly `require` dependencies.
