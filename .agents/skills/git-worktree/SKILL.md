---
name: git-worktree
description: This skill should be used when the user asks to "use git worktree", "migrate away from worktrees", or "handle legacy worktree setup" in this repository.
---

# Git Worktrees

## Role

Use this skill as the canonical owner for optional and legacy worktree workflows in Prisma.

- Own the repository-specific policy for when worktrees are acceptable.
- Provide the minimal command surface for safe worktree creation and cleanup.
- Keep worktrees explicitly secondary to the default single-checkout branch workflow.

## Scope Boundary

- Use this skill for worktree-specific operations and migration away from older worktree setups.
- Use `../git-workflow/SKILL.md` for the default branch/commit/PR workflow.

## When to Use

Use this skill when the user asks to use git worktree, migrate away from worktrees, or handle legacy worktree setup in this repository.

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
- Prefer project targets (`make build-test`) to match CI behavior when running build + test in sequence.

## Common pitfalls

- A branch can only be checked out in one worktree at a time.
- Prefer `git worktree remove` over `rm -rf` to keep Git state consistent.
- Worktrees can multiply build outputs (DerivedData, `.build`); clean up when done.
- For this project, prefer the default branch-only workflow unless you have a specific operational reason.
