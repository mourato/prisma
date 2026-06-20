---
name: git-advanced-workflows
description: This skill should be used when the user asks to "rebase", "cherry-pick", "run git bisect", "use reflog", or "recover complex git history".
---

# Git Advanced Workflows

## Role

Use this skill as the canonical owner for advanced Git history surgery and recovery workflows in Prisma.

- Own rebase, cherry-pick, bisect, reflog, and complex branch-repair guidance.
- Complement, but do not replace, the standard Git workflow skill.
- Keep destructive-history operations explicit and deliberate.

## Scope Boundary

- Use this skill for advanced Git operations and recovery scenarios.
- Use `../git-workflow/SKILL.md` for standard branch, commit, PR, and cleanup flow.
- Use `../git-worktree/SKILL.md` for optional worktree-specific operations.

## When to Use

- cleaning up branch history before merge
- applying a specific fix to another branch
- finding the commit that introduced a regression
- recovering from reset, dropped commits, or bad rebase state
- handling diverged branches where standard flow is no longer enough

## Preferred Order

1. Try the standard flow from `git-workflow` first.
2. Use the least-destructive advanced command that resolves the problem.
3. Before rewriting shared history, confirm whether the branch is already pushed or used by others.
4. Use reflog as the recovery path before escalating further.

## Core Operations

### Interactive rebase

```bash
git rebase -i HEAD~5
git rebase -i $(git merge-base HEAD main)
```

Use it to:

- squash fixup noise
- reorder commits into reviewable units
- split or edit a bad commit
- reword commit messages before review

Common operations:

- `pick`
- `reword`
- `edit`
- `squash`
- `fixup`
- `drop`

### Cherry-pick

```bash
git cherry-pick abc123
git cherry-pick abc123..def456
git cherry-pick -n abc123
```

Use it when one commit should move without merging the whole branch.

### Git bisect

```bash
git bisect start
git bisect bad HEAD
git bisect good <known-good-commit>
git bisect reset
```

Prefer a repo-real test command when possible:

```bash
git bisect run make test-smoke
```

### Reflog

Use reflog whenever a destructive operation went wrong.

```bash
git reflog
git branch recovery <reflog-commit>
```

## Safety Checklist

- Create a recovery branch before major history surgery.
- Prefer `git push --force-with-lease`, never plain `--force`.
- Re-run the appropriate validation after `rebase` or `cherry-pick`.
- Abort and recover early if the operation stops making the history clearer.

## Recovery Commands

```bash
git rebase --abort
git rebase --continue
git rebase --skip
git cherry-pick --abort
git cherry-pick --continue
git bisect reset
git restore --source=<commit> <path>
git reset --soft HEAD^
```

## Related Skills

- `../git-workflow/SKILL.md`
- `../git-worktree/SKILL.md`
