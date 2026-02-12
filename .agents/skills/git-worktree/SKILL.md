---
name: git-worktree
description: This skill should be used when using Git Worktrees for parallel development, managing multiple active branches, or handling dependencies in a worktree-first workflow.
---

# Git Worktrees

Git worktrees let you check out multiple branches into different directories at the same time.

## Mandate: risk-based worktree usage

Follow `AGENTS.md` lane policy:

- **Low risk (Fast lane)**: worktree is recommended.
- **Medium/High risk (Full lane)**: worktree is mandatory.

## This repo layout (recommended)

This repository uses a "bare repo" layout:

- `.bare/` is the actual Git repository (bare)
- `main/` is the main working tree
- task branches live in sibling folders (one folder per worktree)

If you are currently in the `main/` worktree, create a new task worktree like this:

```bash
git worktree add -b codex/<task-name> ../<worktree-folder> main
cd ../<worktree-folder>
```

For Full lane tasks, do not implement changes in `main/`; use `main/` only to create/merge/remove task worktrees.

## Operations cheatsheet

```bash
# List active worktrees
git worktree list

# Add a worktree for an existing branch
git worktree add ../hotfix-login fix/login-issue
cd ../hotfix-login

# Remove a worktree (preferred)
cd ..
git worktree remove hotfix-login

# If you manually deleted a folder, prune stale records
git worktree prune
```

## Dependency notes (Swift)

Each worktree is a fresh directory.

- SwiftPM/Xcode may resolve dependencies per-worktree.
- Prefer project targets (`make build`, `make test`) to match CI behavior.

## Common pitfalls

- A branch can only be checked out in one worktree at a time.
- Prefer `git worktree remove` over `rm -rf` to keep Git state consistent.
- Worktrees can multiply build outputs (DerivedData, `.build`); clean up when done.
- For low-risk micro tasks, forcing worktree setup can add unnecessary overhead; use Fast lane discretion.
