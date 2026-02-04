---
name: git-worktree
description:  Master Git Worktrees for parallel development. Includes the pro "Bare Repository" setup, handling dependencies, and managing multiple active branches simultaneously.
---

# Git Worktree Skill

Git worktrees allow you to check out multiple branches of the same repository into different directories at the same time. This is a game-changer for multitasking, reviewing PRs without context switching, and maintaining long-running experiments.

## 1. Core Concepts

Normally, a Git repo has one "working tree" (where your files are). With worktrees, you can attach multiple working trees to a single `.git` repository.

**When to use:**
*   You're working on `feature-A` and need to fix a critical bug on `main` *right now*.
*   You want to run the app on `release/v1` and `release/v2` simultaneously.
*   You need to review a coworker's complex PR but don't want to mess up your current uncommitted state.

## 2. The "Bare Repository" Strategy (Best Practice)

For heavy worktree users, the cleanest setup is to have a "bare" repository at the root, and *all* branches (including `main`) in subdirectories. This keeps everything organized.

### Structure Goal
```text
my-project/           # The root folder
├── .bare/            # The actual .git directory (bare)
├── main/             # Worktree for main branch
├── feature-xyz/      # Worktree for a feature
└── .git              # File pointing to .bare
```

### Setup Guide
1.  **Clone as bare**:
    ```bash
    git clone --bare git@github.com:org/repo.git .bare
    ```
2.  **Create `.git` file** (trick git into thinking root is a repo):
    ```bash
    echo "gitdir: ./.bare" > .git
    ```
3.  **Fix references** (optional but recommended):
    Edit `config` inside `.bare` to ensure `remote.origin.fetch` includes `+refs/heads/*:refs/remotes/origin/*`.
4.  **Create your main worktree**:
    ```bash
    git worktree add main
    ```

## 3. Operations Cheatsheet

### Creating Worktrees
```bash
# syntax: git worktree add <path> <branch>

# Checkout existing branch to new folder
git worktree add ./hotfix-login fix/login-issue

# Create NEW branch in new folder
git worktree add -b feature/new-ui ./new-ui main
```

### Listing & Removing
```bash
# See all active worktrees
git worktree list

# Remove a worktree (deletes folder & disconnects)
git worktree remove ./hotfix-login
```

### Pruning
If you manually deleted a folder, git thinks the worktree is still there (locked).
```bash
# Clean up stale entries
git worktree prune
```

## 4. Workflows

### Scenario A: The "Quick Fix" (Standard Repo)
You are in a normal cloned repo, deep in changes. A wild bug appears!

1.  **Don't stash.** Just open a new window.
    ```bash
    git worktree add ../my-app-hotfix main
    cd ../my-app-hotfix
    ```
2.  **Fix the bug.**
    ```bash
    # do code changes
    git commit -m "fix: serious bug"
    git push
    ```
3.  **Cleanup.**
    ```bash
    cd ..
    rm -rf my-app-hotfix  # or git worktree remove
    git worktree prune
    ```
4.  **Resume.** Go back to your original terminal. Zero context lost.

### Scenario B: Dependency Management
**Problem:** `node_modules` (or `build/`, `target/`) are usually ignored. Each worktree is a *fresh* directory, so it needs its own dependencies.
**Solution:**
*   **Javascript/Node:** Run `npm install` in every new worktree.
*   **Swift:** Xcode build derivatives are usually global or per-workspace, but you might need to resolve packages again.

**Pro-Tip:** If using the Bare Repo strategy, you can verify if a shared cache works (e.g. `pnpm` store), but generally treat each worktree as an isolated machine.

## 5. IDE Integration (VS Code)

VS Code treats each worktree as a separate project.
1.  Open the *specific worktree folder* as your workspace root (e.g., open `my-project/feature-A`).
2.  Do **not** open the root `my-project` if you used the Bare Repo strategy, as the root itself has no files (just worktree folders).

## 6. Common Pitfalls

*   **Same Branch Twice:** You cannot checkout `main` in two worktrees at once. One worktree per branch.
*   **Stale References:** If you delete the folder manually, use `git worktree prune`.
*   **Disk Space:** Remember `node_modules` x Number of Worktrees = Heavy Disk Usage.

