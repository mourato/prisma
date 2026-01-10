# Git Workflow

> **Skill Condicional** - Ativada quando trabalhando com versionamento

## Visão Geral

Padrões de commits, branches e pull requests para o Meeting Assistant.

## Quando Usar

Ative esta skill quando detectar:
- `git commit`
- `git branch`
- Pull requests
- `.github/PULL_REQUEST_TEMPLATE.md`

## Conceitos-Chave

### Branch Naming

```bash
# Features
feature/audio-recording
feature/settings-persistence

# Bug fixes
fix/transcription-timeout
fix/menubar-crash

# Experimentos
experiment/new-transcription-engine
experiment/ai-enhancements

# Issues específicos
fix/123-audio-dropout
feature/456-cloud-sync
```

### Commit Messages

```
[tipo]: descrição curta (max 50 chars)

Corpo da mensagem opcional, com descrição mais detalhada.
Use frases completas e explique o "por quê".

- Lista de mudanças se necessário
- Referência a issues: #123

Tipos: feat, fix, refactor, docs, test, chore, style, perf
```

```bash
# Exemplos
git commit -m "feat(audio): add noise cancellation filter"
git commit -m "fix(settings): resolve API key persistence issue"
git commit -m "docs: update AGENTS.md with new commands"
git commit -m "refactor(transcription): simplify buffer management"
```

### Pull Requests

Use o template `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Descrição
<!-- O que foi modificado e por quê -->

## Checklist
- [ ] Testes passaram
- [ ]Lint passou
- [ ] Documentação atualizada
- [ ] Breaking changes documentados

## Screenshots (se aplicável)
```

## Patterns Comuns

### Squash Commits

```bash
# Antes de fazer merge, squash commits relacionados
git rebase -i HEAD~n
# Mude "pick" para "squash" para commits relacionados
```

### Correlation de Issues

```bash
# Fecha issue automaticamente
git commit -m "feat(audio): add recording capability

Closes #123"
```

## Técnicas Avançadas

Para operações avançadas de Git, consulte a skill [git-advanced-workflows](../git-advanced-workflows/SKILL.md):

- **Rebase interativo**: pick, reword, squash, fixup, drop
- **Cherry-picking**: commits únicos e em range
- **Git bisect**: busca binária para encontrar bugs
- **Worktrees**: trabalhar em múltiplos branches simultaneamente
- **Reflog**: recuperação de commits deletados

## Referências

- [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md)
- [Conventional Commits](https://www.conventionalcommits.org/)
