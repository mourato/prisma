---
name: code-review
description: Para fazer uma análise crítica (performance, UX, segurança, concorrência, testes) e pragmática do código alterado antes do push final.
---

# Code Review (Meeting Assistant)

## Objetivo

Fazer uma análise crítica e pragmática do código alterado antes do push final, com foco em:

- Correção e concorrência (Swift 6 / `@MainActor` / races)
- Segurança e privacidade (dados sensíveis, logs, permissões)
- Performance (hot paths, alocação, observação/Combine)
- UX (consistência de Settings, estados inválidos, feedback)
- Manutenibilidade (duplicação, coesão, acoplamento, naming)
- Testabilidade (pontos de injeção, pure logic)

## Como executar

1/ **Escopo**

- Liste os commits e os arquivos tocados.
- Identifique mudanças de comportamento vs. mudanças estruturais.

2/ **Checklist técnico**

- **Threading**: mutação de estado acontece no actor certo?
- **Side effects**: atualizações em `UserDefaults` e `KeyboardShortcuts` são consistentes?
- **Estado**: há estados impossíveis (ex.: lock preso)?
- **Falhas**: em caso de erro/cancelamento, estado volta ao normal?
- **Logs**: sem PII; severidade coerente.
- **i18n/a11y**: strings e labels estão corretos?

3/ **Checklist de UX**

- Configurações estão no lugar certo (contextual)?
- “Reset” deixa a UI consistente e previsível?
- Shortcuts “custom” ficam inativos quando não selecionados?

4/ **Checklist de segurança**

- Nada de gravação simultânea conflitante.
- Sem vazamento de paths/inputs sensíveis em logs.

5/ **Resumo final em tabela (semáforo)**
Use uma tabela com prioridade e recomendação:

- 🔴 **Crítico**: bug, risco de crash, perda de dados, segurança
- 🟡 **Médio**: comportamento confuso, dívidas técnicas, performance
- 🟢 **Baixo**: melhorias de clareza, refactors opcionais

Colunas sugeridas:

- Severidade
- Área (UX/Perf/Sec/Conc/Test/Arch)
- Achado
- Impacto
- Recomendação

## Saída esperada

- Uma tabela de resumo (semáforo).
- Observações objetivas com referência a arquivos/símbolos.
- Recomendações “next steps” (curtas e acionáveis).
