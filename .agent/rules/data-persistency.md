---
trigger: always_on
---

- Escolha o armazenamento certo: `UserDefaults` para preferências leves, Core Data para modelos complexos, Realm como alternativa moderna
- Armazene dados sensíveis (senhas, tokens) em Keychain, nunca em defaults ou disco plano
- Planeje migrações de schema desde o início, não como caso de uso tardio
- Implemente backup em iCloud quando apropriado usando CloudKit ou NSUbiquitousKeyValueStore