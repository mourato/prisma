---
name: Git Workflow
description: Master the Git workflow for the Meeting Assistant project, including mandatory worktree-first development, conventional commits, and proactive commit suggestions. Use when managing branches, commits, and pull requests.
---

# Git Workflow

## Overview

Comprehensive Git patterns for branch management, commit standards, and pull requests in the Meeting Assistant project.

## When to Use

Activate this skill whenever you are:
- Starting a new task or conversation that requires code changes.
- Preparing to commit changes or create a pull request.
- Managing branches or historical repository state.
- Following the mandatory Worktree-first development workflow.

## Core Principles

### 1. Mandatory Worktree Workflow
**CRITICAL**: Every session that results in file modifications MUST follow the standard lifecycle described in the **[task-lifecycle](../task-lifecycle/SKILL.md)** skill.
1. **Branching**: Create a NEW branch based on `main`.
2. **Worktree Creation**: Create a new Git Worktree and switch to it.
3. **Verification**: Always run `make build` and `make test` before merging.

### 2. Atomic Commits
Break your work into small, self-contained units.
- **One task = One (or more) Commits**: Do not combine refactoring, bug fixes, and new features.
- **Commit Early & Often**: Capture each logical step (e.g., "add view model", "implement view").
- **Green State**: Every commit must leave the repository in a buildable and testable state.

### 3. Pre-Commit Verification
**CRITICAL**: Before creating ANY commit, you MUST verify project health.
- Run `make build` (or `make build-debug`).
- Ensure relevant tests pass with `make test`.
- Do NOT commit broken code.

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
# From the main directory
git worktree add -b feature/my-new-feature ../my-new-feature main
cd ../my-new-feature
# Execute changes here
```

### Pull Requests

Always use the project PR template and ensure:
- [ ] Build Passed (`make build`)
- [ ] Tests passed (`make test`)
- [ ] Lint passed (`make lint`)
- [ ] Documentation updated

## Advanced Techniques

For complex Git operations, see the **[git-advanced-workflows](../git-advanced-workflows/SKILL.md)** skill:
- Interactive rebase (squashing, reordering)
- Cherry-picking specific commits
- Troubleshooting with `git bisect`
- History recovery with `reflog`

## References

- [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md)
- [Conventional Commits Specification](https://www.conventionalcommits.org)
