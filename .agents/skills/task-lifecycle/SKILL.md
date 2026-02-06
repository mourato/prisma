---
name: task-lifecycle
description: This skill should be used when following the project's task lifecycle, from initialization and branching to implementation, verification, and cleanup.
trigger: always_on
---

# Universal Task Lifecycle

## Overview

This skill defines the **MANDATORY** operational standards for every coding task performed on this codebase. It ensures environment isolation, code safety, and a clean repository history.

## Phase 1: Task Initialization

**CRITICAL**: Never modify files in the `main/` worktree. Always create a dedicated task worktree first.

1. **Context Identification**: Analyze the task and identify the target files.
2. **Branching**: Create a fresh branch from `main` (for Codex sessions prefer `codex/<task-name>`).
3. **Setup Worktree**: Create and enter a new Git Worktree.
   ```bash
   git worktree add -b <branch-name> ../<folder-name> main
   cd ../<folder-name>
   ```

## Phase 2: Implementation & Verification

Language policy:

- Documentation must be written in **English**.
- Code comments must be written in **English**.


Work exclusively within the isolated worktree directory.

1. **Incremental Commits**: Commit logically related changes frequently using Conventional Commits.
2. **Continuous Verification**: Periodically run `make arch-check`, `make build`, and `make test` to ensure stability.
   - For B2 modularization work, verify both compile and tests after each access-control/import change.
   - If tests touch module internals, ensure the test target depends on that module explicitly in `Package.swift`.
3. **Documentation**: Update `KNOWN_LIMITATIONS.md` or DocC comments if the implementation introduces new constraints or APIs.

## Phase 3: Finalization & Cleanup

Once the task is complete and verified:

1. **Merge**: Return to the `main` directory and merge the task branch.
   ```bash
   cd ../main
   git merge <branch-name>
   ```
2. **Cleanup Directory**: Remove the worktree folder.
   ```bash
   rm -rf ../<folder-name>
   git worktree prune
   ```
3. **Delete Branch**: Delete the temporary local branch.
   ```bash
   git branch -D <branch-name>
   ```

## References

- **[git-workflow](../git-workflow/SKILL.md)**: Detailed commit and branching guidelines.
- **[quality-assurance](../quality-assurance/SKILL.md)**: Standards for testing and build verification.
