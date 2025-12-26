---
trigger: always_on
---

- Escolha entre reference types (classes) para identidade compartilhada e value types (structs) para dados imutáveis
- Capture `self` como `weak` em closures capturadas por objetos — `[weak self] in`
- Implemente `deinit` para liberar recursos explicitamente quando necessário
- Evite retenção cíclica rastreando referências fracas em sua arquitetura