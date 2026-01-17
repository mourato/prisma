# Testing Strategy

> **Última Atualização:** 2026-01-17
> **Tags:** #Testing, #Mocks, #Performance, #XCTest

## 1. Contexto (Why)
Testes confiáveis são a base para refatoração e evolução segura. Este documento define como criamos mocks, medimos performance e isolamos estados globais (Actors/Managers) para evitar testes intermitentes (flaky tests).

## 2. Diretrizes (What & How)

### Mocks & Doubles
- **Geração Automática**: Use scripts ou ferramentas de geração de mocks para protocolos complexos.
  - *Exemplo*: Arquivo `GeneratedMocks.swift` centraliza os mocks.
- **Protocol-First**: Dependa sempre de protocolos, nunca de implementações concretas em ViewModels ou Services.

### Testes de Performance
- **Baseline**: Use `XCTMetric` para estabelecer baselines de performance em operações críticas (ex: Áudio).
- **Reset de Estado**: Para singletons ou atores globais (`RecordingManager`, `RecordingActor`), implemente um método `reset()` acessível apenas em testes (`internal` ou via flag de compilação) para limpar o estado entre execuções.

### Isolamento
- **Global Actors**: Cuidado com estados compartilhados. Se um teste modifica um Manager global, ele deve limpá-lo no `tearDown`.
- **Concurrency**: Use `expectation` para testar código assíncrono. Evite `sleep()` arbitrário.

## 3. Exemplos Práticos

### Resetando Estado em Testes
Padrão para garantir isolamento em testes de performance ou integração:

```swift
// No código de produção (interno ou debug)
actor RecordingActor {
    func reset() {
        self.state = .idle
        self.buffer.clear()
    }
}

// No Teste
override func tearDown() async throws {
    await RecordingContainer.shared.recordingActor.reset()
}
```

### Medindo Performance
```swift
func testHotPathPerformance() {
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
        // Operação crítica a ser medida
        engine.processBuffer()
    }
}
```

## 4. Referências Cruzadas
- `docs/ARCHITECTURE.md` (Para entender componentes de Áudio)
- `docs/QUALITY_ASSURANCE.md`
