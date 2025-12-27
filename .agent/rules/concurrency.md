---
trigger: always_on
---

- Segurança de Thread: Use `Actor`, `@MainActor` ou mecanismos de locking adequados
- Evite `@unchecked Sendable` a menos que absolutamente necessário
- Prefira `Async/Await` e estruturas modernas de concorrência em vez de callbacks
- **Lock Safety (Audio)**: NUNCA use `NSLock` em callbacks de áudio. Use `OSAllocatedUnfairLock`.
- **Sendable**: Closures entre threads DEVEM ser `@Sendable`.
