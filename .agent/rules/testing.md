---
trigger: always_on
---

- Isole unit tests mockando todas as dependências externas
- Mantenha cobertura acima de 80% nas camadas críticas
- Evite testes UI — eles são frágeis e lentos; use-os com moderação
- Mock networking com bibliotecas como OHHTTPStubs para testes determinísticos
- Implemente métodos `reset()` em global Actors/Managers para isolamento entre testes (acessível via `internal` ou flag de compilação)
- Use `XCTMetric` para estabelecer performance baselines em operações críticas (ex: audio hot path)
- Use `expectation` para testes assíncronos; evite `sleep()` arbitrário
- Para Protocol-First design, gere mocks automaticamente e centralize em `GeneratedMocks.swift`