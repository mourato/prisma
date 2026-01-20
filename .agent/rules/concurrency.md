---
trigger: always_on
---

- Use `Actor`, `@MainActor` ou mecanismos de locking adequados para segurança de thread
- Evite `@unchecked Sendable` a menos que absolutamente necessário
- Prefira `Async/Await` e estruturas modernas de concorrência em vez de callbacks
- Closures passadas entre threads DEVEM ser marcadas `@Sendable`
- Para áudio real-time, veja `audio-realtime.md` para regras específicas de lock safety

## Deadlock Prevention

### AudioBufferQueue e Ring Buffers

- **CRÍTICO**: Propriedades computed que adquirem locks podem causar deadlocks em contextos multi-threaded
- Prefira implementações simples sem locks aninhados:
  ```swift
  // ❌ INCORRETO - Deadlock risk
  var isEmpty: Bool {
      lock.withLock { /* lógica complexa */ }
  }

  // ✅ CORRETO - Single lock acquisition
  var isEmpty: Bool {
      count == 0  // 'count' já usa lock internamente
  }
  ```
- Ao debugar deadlocks em testes (ex: `testDequeue_EmptyQueueAfterDequeuing`), verifique propriedades computed
- Use `OSAllocatedUnfairLock` **uma vez** por operação, nunca aninhado
- Evite adquirir múltiplos locks simultaneamente; se necessário, estabeleça ordem consistente

## Swift 6 Strict Concurrency

- Sempre marque closures entre threads como `@Sendable`
- ViewModels que interagem com actors devem ser `@MainActor`
- **Erro comum**: "Capture of 'self' in closure requires sendable conformance"
  - **Solução**: Use `@Sendable` no tipo da closure ou `[weak self]` + verificação de sendability
  
```swift
// ✅ CORRETO - Closure sendable explícita
typealias CompletionHandler = @Sendable (Result<Data, Error>) -> Void

// ✅ CORRETO - ViewModels isolados
@MainActor
class AISettingsViewModel: ObservableObject {
    func updateSettings() async {
        // Safe - isolated to MainActor
    }
}

// ✅ CORRETO - Weak self em contexto sendable
someAsyncMethod { [weak self] result in
    await MainActor.run {
        self?.handleResult(result)
    }
}
```