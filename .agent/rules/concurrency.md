---
trigger: always_on
---

- Segurança de Thread: Use `Actor`, `@MainActor` ou mecanismos de locking adequados
- Evite `@unchecked Sendable` a menos que absolutamente necessário
- Prefira `Async/Await` e estruturas modernas de concorrência em vez de callbacks
