---
trigger: always_on
---

- Evite `Any` e `NSObject` — eles comprometem o sistema de tipos do Swift
- Use `Result<Success, Failure>` para retornar sucesso ou erro de forma type-safe
- Modele estados complexos com enums que contêm associated values
- Recuse unwrapping forçado — use `guard let` e `if let` para opcionais
- Implemente `Codable` para JSON em vez de usar dicionários genéricos