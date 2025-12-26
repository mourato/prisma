---
trigger: always_on
---

- Minimize dependências — cada pacote adiciona risco de manutenção
- Prefira Swift Package Manager como gestor de dependências padrão
- Especifique versões explicitamente — use `.upToNextMajor` em vez de wildcard
- Audite regularmente pacotes para vulnerabilidades e atualizações