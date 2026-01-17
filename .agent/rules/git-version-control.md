---
trigger: always_on
---

# Versionamento Git e Sugestões de Commit

## Princípios Gerais

- **Commits Atômicos**: Cada commit deve representar uma mudança lógica completa e autocontida. Evite misturar múltiplas preocupações em um único commit (ex: refatoração + correção de bug + nova feature).
- **Commits Frequentes**: Prefira commits menores e mais frequentes a commits grandes e raros. Isso facilita o rastreamento de bugs e o revert de mudanças.
- **Mensagens Descritivas**: Siga o padrão Conventional Commits: `tipo(escopo): descrição`. Exemplos: `feat(audio): add cancelamento de ruído`, `fix(settings): resolver problema de persistência de API key`.

## Fluxo de Commit Proativo

### Quando Sugerir Commit

**Sugerir commit automaticamente quando:**

1. **Tarefa Concluída**: Após executar `attempt_completion`, verificar se há modificações não commitadas.
2. **Múltiplas Modificações**: Após modificar 5 ou mais arquivos em uma única sessão de conversa.
3. **Antes de Nova Tarefa**: Ao iniciar uma nova tarefa significativa, sugerir commit das mudanças pendentes.
4. **Mudanças Significativas**: Após criar novos arquivos, modificar arquivos de configuração essenciais, ou alterar APIs públicas.

## Boas Práticas de Versionamento

- **Não commitar código quebrado**: Always ensure code compiles and tests pass before committing.
- **Revisar antes de commit**: Usar `git diff` para revisar mudanças pendentes.
- **Evitar commit de arquivos desnecessários**: Configurar `.gitignore` adequadamente.
- **Commits em português/inglês**: Manter consistência no idioma das mensagens (recomendado: inglês para código aberto, português para projetos internos).
- **Referenciar issues**: Incluir números de issue quando aplicável: `Closes #123`, `Relates to #456`.

## Ferramentas de Suporte

- Usar `git status` para verificar estado do repositório
- Usar `git diff` para revisar mudanças
- Usar `git log --oneline` para ver histórico recente
- Usar `git stash` para salvar mudanças temporariamente

## Comprehensive Guidance

For complete workflows, branch naming, pull requests, and advanced techniques, see:
- **[git-workflow skill](.agent/skills/git-workflow/SKILL.md)** - Complete Git workflow patterns and commit suggestions
- **[git-advanced-workflows skill](.agent/skills/git-advanced-workflows/SKILL.md)** - Advanced techniques (rebase, cherry-pick, bisect)
