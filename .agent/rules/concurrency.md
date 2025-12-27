---
trigger: always_on
---

- Use `Actor`, `@MainActor` ou mecanismos de locking adequados para segurança de thread
- Evite `@unchecked Sendable` a menos que absolutamente necessário
- Prefira `Async/Await` e estruturas modernas de concorrência em vez de callbacks
- Closures passadas entre threads DEVEM ser marcadas `@Sendable`
- Para áudio real-time, veja `audio-realtime.md` para regras específicas de lock safety