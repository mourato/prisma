---
name: task-lifecycle
description: Mandatory project standards for the entire task lifecycle, from initialization to cleanup. Use as the definitive guide for starting and finishing work.
trigger: always_on
---

# Universal Task Lifecycle

## Overview

This skill defines the **MANDATORY** operational standards for every coding task performed on this codebase. It ensures environment isolation, code safety, and a clean repository history.

## Phase 1: Task Initialization

**CRITICAL**: Never modify files directly on the `main` branch or in the default project directory.

1. **Context Identification**: Analyze the task and identify the target files.
2. **Branching**: Create a fresh branch from `main` (e.g., `feature/task-name`, `fix/issue-id`).
3. **Setup Worktree**: Create and enter a new Git Worktree.
   ```bash
   git worktree add -b <branch-name> ../<folder-name> main
   cd ../<folder-name>
   ```

## Phase 2: Implementation & Verification

Work exclusively within the isolated worktree directory.

1. **Incremental Commits**: Commit logically related changes frequently using Conventional Commits.
2. **Continuous Verification**: Periodically run `make build` and `make test` to ensure stability.
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
