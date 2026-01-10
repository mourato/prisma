# Git Workflow

> **Conditional Skill** - Triggered when working with version control

## Overview

Commit, branch, and pull request patterns for the Meeting Assistant project.

## When to Use

Activate this skill when detecting:
- `git commit`
- `git branch`
- Pull requests
- `.github/PULL_REQUEST_TEMPLATE.md`

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

```
[type]: short description (max 50 chars)

Optional body with more detailed description.
Use complete sentences and explain the "why".

- List of changes if needed
- Reference issues: #123

Types: feat, fix, refactor, docs, test, chore, style, perf
```

```bash
# Examples
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

## References

- [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md)
- [Conventional Commits](https://www.conventionalcommits.org)
