# Quality Assurance & Automation

> **Última Atualização:** 2026-01-17
> **Tags:** #Linting, #Formatting, #CI/CD, #GitHooks

## 1. Contexto (Why)
Para manter a consistência do código, prevenir erros comuns e agilizar o code review, adotamos ferramentas automatizadas de análise estática e formatação. Isso remove a carga cognitiva de discutir "estilo" nos Pull Requests e foca o time na lógica e arquitetura.

## 2. Diretrizes (What & How)

### Linting & Formatting
- **Ferramentas Oficiais**:
  - `SwiftLint`: Para análise estática e enforcement de regras de estilo.
  - `SwiftFormat`: Para formatação automática do código.
- **Regra Principal**: O código **não deve ser commitado** se houver avisos (warnings) críticos ou erros de lint.
- **Pre-Commit Hooks**: Scripts configurados no git (`.git/hooks/pre-commit`) rodam a verificação automaticamente. **Não ignore** os hooks (`--no-verify`) exceto em emergências absolutas.

### Pull Request Checks
- **Danger Swift**: Utilizado em CI (GitHub Actions) para automatizar feedbacks em PRs.
- **Escopo**: Verifica tamanho do PR, descrição, warnings do compilador e resultados de testes.

### Build Phases
- **Script de Build**: O projeto contém Build Phases no Xcode que rodam SwiftLint/SwiftFormat. Se o build falhar por lint, corrija o código, não remova o script.

## 3. Exemplos Práticos

### Rodando Verificações Manualmente
Para verificar o projeto localmente sem esperar o commit:

```bash
# Rodar SwiftLint
swiftlint lint

# Rodar SwiftFormat
swiftformat .
```

### Setup de Desenvolvimento
Ao clonar o repositório, certifique-se de instalar as ferramentas:

```bash
brew install swiftlint swiftformat
# Instalar hooks (se houver script de setup)
./scripts/setup-hooks.sh
```

## 4. Referências Cruzadas
- `.agent/rules` (Veja regras universais de Clean Code)
- `docs/BEST_PRACTICES.md`
