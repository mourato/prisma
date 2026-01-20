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

## Mock Generation com Cuckoo

- Use `make mocks` para regenerar mocks após mudanças em protocolos
- Mocks são gerados via `CuckooGenerator` configurado em `Cuckoofile.toml`
- **CRÍTICO**: Métodos `async` em mocks DEVEM ter `await` nos stubs:
  ```swift
  // ✅ CORRETO
  stub(mock) { mock in
      when(mock.process()).thenReturn(await defaultValue())
  }
  
  // ❌ INCORRETO - Erro de compilação
  stub(mock) { mock in
      when(mock.process()).thenReturn(defaultValue())
  }
  ```
- Ao modificar protocolos mockados, sempre execute `make mocks` antes de rodar testes
- Problemas com unwrapping forçado em testes podem indicar mocks desatualizados
- Se testes falharem após mudanças em protocols, verifique primeiro se `GeneratedMocks.swift` está atualizado