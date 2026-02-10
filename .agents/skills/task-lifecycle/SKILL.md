---
name: task-lifecycle
description: This skill should be used when following the project's task lifecycle, from initialization and branching to implementation, verification, and cleanup.
trigger: always_on
---

# Universal Task Lifecycle

## Overview

This skill defines the **MANDATORY** operational standards for every coding task performed on this codebase.

The lifecycle is designed to guarantee:
- Isolation via Worktrees
- A continuously green repository state (build/tests)
- Atomic commits (small, intention-revealing, buildable)
- A consistent local code review ritual before final push/merge
- Cleanup (worktree + branches, including remote when applicable)

## Phase 1: Task Initialization

**CRITICAL**: Never modify files in the `main/` worktree. Always create a dedicated task worktree first.

1. **Context Identification**: Analyze the task and identify the target files.
2. **Branching**: Create a fresh branch from `main` (for Codex sessions prefer `codex/<task-name>`).
3. **Setup Worktree**: Create and enter a new Git Worktree.
   ```bash
   git worktree add -b <branch-name> ../<folder-name> main
   cd ../<folder-name>
   ```

## Phase 2: Implementation Loop (Green + Atomic)

Language policy:

- Documentation must be written in **English**.
- Code comments must be written in **English**.


Work exclusively within the isolated worktree directory.

Repeat the following loop until the task is complete:

1. **Implement a small, coherent slice**: Prefer incremental changes.
2. **Verify BEFORE committing (hard gate)**:
   - `make build`
   - `make test`
   - (recommended) `make lint`
   - Periodically run `make arch-check` (especially for B2 modularization and access-control/import updates).
   - If tests touch module internals, ensure the test target depends on that module explicitly in `Package.swift`.
3. **If verification fails**: Stop and fix until it passes. Do **not** commit broken builds.
4. **Atomic commit (green state)**:
   - Group changes by intent.
   - Use Conventional Commits.
   - Every commit must leave the repo buildable + testable.
5. **Documentation**: Update `KNOWN_LIMITATIONS.md` / DocC if the change introduces new constraints or APIs.

> This phase is intentionally strict: “green before commit” keeps history bisectable and reduces review noise.

## Phase 3: Local Code Review Ritual (Mandatory)

Before the final push/merge, perform a local review using **[code-review](../code-review/SKILL.md)**.

1. **Define the scope**: Review the commit list and files touched.
2. **Produce a semáforo table** (🔴/🟡/🟢) as specified in the skill.
3. **Fix findings**:
   - Must fix **🔴 Critical** and **🟡 Medium**.
   - Fix **🟢 Low** when it clearly improves clarity/safety with low risk.
4. **Re-verify**:
   - `make build`
   - `make test`
   - (recommended) `make lint`
5. **Atomic commits for review fixes**: Commit review-driven changes separately from feature work.

## Phase 4: Integration (Push / Merge)

1. **Push the branch** (for PR or collaboration):
   ```bash
   git push -u origin <branch-name>
   ```
2. **Merge into `main`** using the team’s preferred approach (PR or local merge).
   - If merging locally, return to the `main` worktree and merge:
     ```bash
     cd ../main
     git merge <branch-name>
     ```

## Phase 5: Cleanup (Mandatory)

Once the task is complete and verified:

1. **Cleanup Directory**: Remove the worktree folder.
   ```bash
   rm -rf ../<folder-name>
   git worktree prune
   ```
2. **Delete local branch** (never delete `main`):
   ```bash
   git branch -D <branch-name>
   ```
3. **Delete remote branch (if it was pushed)**:
   ```bash
   git push origin --delete <branch-name>
   ```

## References

- **[git-workflow](../git-workflow/SKILL.md)**: Detailed commit and branching guidelines.
- **[quality-assurance](../quality-assurance/SKILL.md)**: Standards for testing and build verification.
- **[code-review](../code-review/SKILL.md)**: Mandatory pre-push review ritual and reporting format.
- **[git-worktree](../git-worktree/SKILL.md)**: Worktree operations, pitfalls, and cleanup.
