---
trigger: always_on
---

- Mantenha funções pequenas (máx. 20 linhas) com uma única responsabilidade
- Nomeie variáveis e funções com clareza descritiva — `userData` em vez de `data`
- Prefira condicionais achatadas com `guard` e retornos antecipados; evite aninhamento de `if`
- Escreva comentários que expliquem "por quê", não "o quê"
- Execute `swiftlint` antes de commitar para garantir conformidade com as regras do projeto