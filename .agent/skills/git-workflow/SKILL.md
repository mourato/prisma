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
- Proactive commit suggestions (see "When to Suggest Commit" below)

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

---

## When to Suggest Commit

This skill also activates when proactive commit suggestions are needed. Trigger this section when:

- Task completed with `attempt_completion`
- Multiple files modified (5+ in a session)
- Before starting a new significant task
- After creating new files or modifying config files

### Suggested Workflow

1. Check `git status` to see modified files
2. Use `ask_followup_question` to offer commit options:
   - Commit now with descriptive message
   - View diff first
   - Defer for later
   - Check full status
3. Execute user's choice or record for later

### Example Suggestion Message

```
**Modificações detectadas**: X arquivo(s) modificado(s), Y novo(s), Z deletado(s)

Gostaria de fazer commit das alterações?

1. **Fazer commit agora** - Criar commit com mensagem descritiva
2. **Ver diff primeiro** - Mostrar alterações antes de commitar
3. **Adicionar mais tarde** - Adiar commit para após próximas mudanças
4. **Verificar status** - Mostrar status completo do repositório
```
