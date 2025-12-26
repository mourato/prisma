---
trigger: always_on
---

- Isole unit tests mockando todas as dependências externas
- Mantenha cobertura acima de 80% nas camadas críticas
- Evite testes UI — eles são frágeis e lentos; use-os com moderação
- Mock networking com bibliotecas como OHHTTPStubs para testes determinísticos