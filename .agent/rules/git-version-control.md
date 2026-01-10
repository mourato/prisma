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

### Como Sugerir Commit

Após detectar modificações pendentes, usar `ask_followup_question` para sugerir:

```
**Modificações detectadas**: X arquivo(s) modificado(s), Y novo(s), Z deletado(s)

Gostaria de fazer commit das alterações?

1. **Fazer commit agora** - Criar commit com mensagem descritiva
2. **Ver diff primeiro** - Mostrar alterações antes de commitar
3. **Adicionar mais tarde** - Adiar commit para após próximas mudanças
4. **Verificar status** - Mostrar status completo do repositório
```

### Exemplos de Mensagens de Commit

```bash
# Nova funcionalidade
feat(recording): add suporte a gravação de áudio do sistema

# Correção de bug
fix(transcription): resolver timeout em transcrições longas

# Documentação
docs: atualizar AGENTS.md com novos comandos de build

# Refatoração
refactor(audio-buffer): simplificar gerenciamento de buffer

# Testes
test(recording-manager): add testes para estado de gravação

# Chore (tarefas de manutenção)
chore(dependencies): atualizar Swift Package Manager dependencies
```

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
