---
trigger: always_on
---

- Ordem de Importação: Siga a ordem alfabética ou lógica (ex: CoreML, Foundation, OSLog)
- Nomenclatura: lowerCamelCase para variáveis/funções, UpperCamelCase para tipos
- Documentação: Use comentários de barra tripla (///) para APIs públicas
- Fluxo de Controle: Prefira condicionais achatadas (flattened) com `guard` e retornos antecipados; evite aninhamento de `if`
- Nomeie variáveis e funções com clareza descritiva — `userData` em vez de `data`
- Mantenha funções pequenas com uma única responsabilidade
- Prefira computed properties e inicializadores customizados a métodos auxiliares dispersos
- Escreva comentários que expliquem "por quê", não "o quê"
- **Linting & Formatting**: Mantenha o código em conformidade com as regras do SwiftLint e SwiftFormat definidas no projeto. Execute \`swiftlint\` antes de commitar.
