---
name: git-workflow
description: This skill should be used when the user asks for standard Git flow such as "create branch", "commit changes", "prepare PR", or "merge safely".
---

# Git Workflow

## Overview

Comprehensive Git patterns for branch management, commit standards, and pull requests in the Meeting Assistant project.

## When to Use

Activate this skill whenever you are:
- Starting a new task or conversation that requires code changes.
- Preparing to commit changes or create a pull request.
- Managing branches or historical repository state.
- Applying the risk-based Fast/Full workflow from `AGENTS.md`.

## Core Principles

### 1. Risk-based Branch Workflow
Follow `AGENTS.md` lane selection:
1. **Low risk (Fast lane)**: use a feature branch in the current checkout.
2. **Medium/High risk (Full lane)**: use an isolated feature branch in the current checkout.
3. **Before merge**: apply lane hard gates (`make test` for Fast; `make build && make test` for Full).

### 2. Atomic Commits
Break your work into small, self-contained units.
- **One task = One (or more) Commits**: Do not combine refactoring, bug fixes, and new features.
- **Commit Early & Often**: Capture each logical step (e.g., "add view model", "implement view").
- **Safe State**: Do not commit knowingly broken code.

### 3. Pre-Commit Verification
Before creating a commit, run proportional checks:
- Fast lane: staged lint/format and targeted tests when relevant.
- Full lane: targeted tests and/or `make build` while iterating.
- Run `make arch-check` only when architecture boundaries/access-control are affected.
- Run `make preview-check` when SwiftUI views are added/changed.

### 4. Pre-Push / Pre-Merge Code Review
Before the final push/merge, perform a local review using **[code-review](../code-review/SKILL.md)**.

- Fast lane: lightweight checklist review is acceptable.
- Full lane: create a semáforo report (🔴/🟡/🟢).
- Fix **🔴 Critical** and **🟡 Medium** findings.
- Re-verify lane hard gate and commit fixes atomically.

### 5. Hard Gates by Lane
- **Fast lane (Low risk)**: `make test` before push/merge.
- **Full lane (Medium/High risk)**: `make build` + `make test` before push/merge.
- `make lint` is recommended and mandatory for broad refactors.

## Key Concepts

### Branch Naming Convention

```bash
# Features
feature/audio-recording
feature/settings-persistence

# Bug fixes
fix/transcription-timeout
fix/menubar-crash

# Experiments
experiment/new-transcription-engine

# Issue-bound
fix/123-audio-dropout
feature/456-cloud-sync
```

### Commit Messages (Conventional Commits)

Follow the standard `[type](scope): description` pattern:

```text
[type](scope): short description (max 50 chars)

Optional body explaining the "why" behind the change.
Use complete sentences and reference issues: #123.

Types: feat, fix, refactor, docs, test, chore, style, perf
```

**Examples:**
- `feat(audio): add noise cancellation filter`
- `fix(settings): resolve API key persistence issue`
- `refactor(transcription): simplify buffer management`

### Proactive Commit Suggestions

Suggest committing changes automatically when:
1. **Task Completed**: After finishing a significant unit of work.
2. **Multiple Modifications**: After modifying 5 or more files in a session.
3. **Context Shift**: Before starting a fundamental change or a new task.
4. **Config/API Changes**: After updating critical configuration files or public APIs.

## Practical Workflows

### Standard Task Initialization

```bash
git checkout main
git pull --ff-only
git checkout -b feature/my-new-feature
```

### Pull Requests

If the repository has a PR template, use it.

Before opening a PR (or before merging locally), ensure:
- [ ] Lane hard gate passed (`make test` for Fast; `make build && make test` for Full)
- [ ] Review findings fixed (all 🔴/🟡)
- [ ] Lint completed when required by scope
- [ ] Documentation updated when behavior/contracts changed

### GitHub CLI Body Safety

When sending multiline or formatted text to GitHub via `gh`, prefer `--body-file` over inline `--body`.
This avoids shell parsing/interpolation issues (especially with backticks and mixed-language text).

```bash
# Issue comment
cat <<'EOF' >/tmp/gh-comment.md
Implemented transcript quality alignment end-to-end.
- Added ASR confidence propagation
- Added transcript quality persistence
EOF
gh issue comment 103 --body-file /tmp/gh-comment.md

# Create or edit issue/PR body
cat <<'EOF' >/tmp/gh-body.md
## Summary
Detailed multiline content here.
EOF
gh issue edit 103 --body-file /tmp/gh-body.md
gh pr edit 456 --body-file /tmp/gh-body.md
```

### Branch Cleanup (After Merge)

After merging into `main`, remove temporary branches (never delete `main`).

```bash
# Local branch
git branch -D <branch-name>

# Remote branch (if pushed)
git push origin --delete <branch-name>
```

## Advanced Techniques

For complex Git operations, see the **[git-advanced-workflows](../git-advanced-workflows/SKILL.md)** skill:
- Interactive rebase (squashing, reordering)
- Cherry-picking specific commits
- Troubleshooting with `git bisect`
- History recovery with `reflog`

## References

- [Conventional Commits Specification](https://www.conventionalcommits.org)
