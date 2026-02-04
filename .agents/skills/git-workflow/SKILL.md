---
name: Git Workflow
description: This skill should be used when the user mentions "git commit", "git branch", "pull request", "conventional commits", "branch naming", "squash commits", or needs guidance on version control best practices and proactive commit suggestions.
---

# Git Workflow

## Overview

Commit, branch, and pull request patterns for the Meeting Assistant project.

## When to Use

Activate this skill when working with:
- Git commits and commit messages
- Branch creation and naming
- Pull requests
- Proactive commit suggestions
- Version control workflows

## Core Principles

### 1. Pre-Commit Build Verification
**CRITICAL**: Before creating ANY commit, you MUST verify that the project builds successfully.
- Run `make build` (or `make build-debug`) in the terminal.
- If the build fails, **DO NOT COMMIT**. Fix the errors first.
- If you are modifying a specific module, ensure its tests pass with `make test`.

### 2. Atomic Commits
Break your work into small, self-contained units.
- **One task = One (or more) Commits**: Do not combine refactoring, bug fixes, and new features in a single commit.
- **Commit Early & Often**: Do not wait until the entire feature is done. Commit each logical step (e.g., "add view model", "implement view", "connect service").
- **Green State**: Ensure every commit leaves the repo in a buildable state.

## Key Concepts

### Branch Naming

```bash
# Features
feature/audio-recording
feature/settings-persistence

# Bug fixes
fix/transcription-timeout
fix/menubar-crash

# Experiments
experiment/new-transcription-engine
experiment/ai-enhancements

# Specific issues
fix/123-audio-dropout
feature/456-cloud-sync
```

### Commit Messages

Follow the Conventional Commits specification:

```
[type]: short description (max 50 chars)

Optional body with more detailed description.
Use complete sentences and explain the "why".

- List of changes if needed
- Reference issues: #123

Types: feat, fix, refactor, docs, test, chore, style, perf
```

**Examples:**
```bash
git commit -m "feat(audio): add noise cancellation filter"
git commit -m "fix(settings): resolve API key persistence issue"
git commit -m "docs: update AGENTS.md with new commands"
git commit -m "refactor(transcription): simplify buffer management"
```

### Pull Requests

Use the template `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Description
<!-- What was modified and why -->

## Checklist
- [ ] **Build Passed** (`make build`)
- [ ] Tests passed
- [ ] Lint passed
- [ ] Documentation updated
- [ ] Breaking changes documented

## Screenshots (if applicable)
```

## Common Patterns

### Squash Commits

```bash
# Before merging, squash related commits
git rebase -i HEAD~n
# Change "pick" to "squash" for related commits
```

### Issue Correlation

```bash
# Close issue automatically
git commit -m "feat(audio): add recording capability

Closes #123"
```

## Advanced Techniques

For advanced Git operations, see the [git-advanced-workflows](../git-advanced-workflows/SKILL.md) skill:

- **Interactive rebase**: pick, reword, squash, fixup, drop
- **Cherry-picking**: single and range commits
- **Git bisect**: binary search for bugs
- **Worktrees**: work on multiple branches simultaneously
- **Reflog**: recover deleted commits

## Proactive Commit Suggestions

This skill also activates when proactive commit suggestions are needed. Trigger when:

- Task completed with `attempt_completion`
- Multiple files modified (5+ in a session)
- Before starting a new significant task
- After creating new files or modifying config files

### Suggested Workflow

1. **Verify Build**: Run `make build` to ensure no errors.
2. Check `git status` to see modified files
3. Use `ask_followup_question` to offer commit options:
   - Commit now with descriptive message
   - View diff first
   - Defer for later
   - Check full status
3. Execute user's choice or record for later

### Example Suggestion Message

```
**Detected modifications**: X file(s) modified, Y new, Z deleted

Would you like to commit these changes?

1. **Commit now** - Create commit with descriptive message
2. **View diff first** - Show changes before committing
3. **Add later** - Defer commit until after next changes
4. **Check status** - Show full repository status
```

## User-Specific Requirement

When the user explicitly asks to commit changes, always split the work into multiple smaller commits, grouping related changes logically.

## References

- [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md)
- [Conventional Commits](https://www.conventionalcommits.org)
- [git-advanced-workflows](../git-advanced-workflows/SKILL.md) - Advanced Git techniques
