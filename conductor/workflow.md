# Project Workflow

## Guiding Principles

1. **The Plan is the Source of Truth:** All work must be tracked in `plan.md`
2. **The Tech Stack is Deliberate:** Changes to the tech stack must be documented in `tech-stack.md` *before* implementation
3. **Test-Driven Development (TDD):**
   - For Nix: Write failing checks in `flake.nix` or separate test modules before implementation.
   - For Lua: Write failing tests using a Lua testing framework (if applicable) or define expected behavior clearly.
4. **High Code Quality:**
   - **Nix:** Ensure `nix flake check` passes.
   - **Formatting:** All code must be formatted (`nixfmt`, `lua-format`).
5. **Atomic Commits:** Commit changes after **every** completed task in the plan.
6. **Traceability:** Use Git Notes to attach a summary to each task commit.

## Task Workflow

All tasks follow a strict lifecycle:

### Standard Task Workflow

1. **Select Task:** Choose the next available task from `plan.md`.
2. **Mark In Progress:** Update `plan.md` task from `[ ]` to `[~]`.
3. **Red Phase (Define Expectations):**
   - **Nix:** Create a test case or define the expected output of `nix flake check` that currently fails or would fail without the new module.
   - **Lua:** Write a failing test or script.
4. **Green Phase (Implement):**
   - Write the minimum configuration/code to satisfy the requirement.
   - Verify `nix flake check` passes.
   - Verify the configuration builds (`darwin-rebuild build --flake .` or `home-manager build --flake .`).
5. **Refactor:** Clean up the code while ensuring checks still pass.
6. **Verify Standards:**
   - Run formatters: `nixfmt **/*.nix`
   - Run linters/checks: `nix flake check`
7. **Commit Code:**
   - Stage changes.
   - Commit with conventional message: `feat(git-ai): Add initial module structure`.
8. **Attach Task Summary (Git Notes):**
   - Get commit hash: `git log -1 --format="%H"`
   - Draft note: Summary of changes, files modified, reasoning.
   - Attach note: `git notes add -m "<summary>" <commit_hash>`
9. **Update Plan:**
   - Mark task as `[x]` in `plan.md`.
   - Append commit hash: `[x] Task name <commit_hash>`
10. **Commit Plan:** `conductor(plan): Mark task '...' as complete`.

## Quality Gates

Before marking any task complete, verify:

- [ ] `nix flake check` passes.
- [ ] Code is formatted.
- [ ] No regression in existing functionality.
- [ ] Documentation updated (if new options added).
