---
name: git-worktree
description: This skill should be used when the user asks to "use git worktree", "migrate away from worktrees", or "handle legacy worktree setup" in this repository.
---

# Git Worktrees

Git worktrees let you check out multiple branches into different directories at the same time.

Project default: do not use worktrees for routine development. Use a single checkout with feature branches.

## Policy

Worktrees are optional and should be used only for migration/maintenance scenarios.

## Optional operations cheatsheet

If you choose to use worktrees in a local experiment, use standard Git operations:

```bash
git worktree add -b codex/<task-name> ../<worktree-folder> main
cd ../<worktree-folder>
```

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
- For this project, prefer the default branch-only workflow unless you have a specific operational reason.
