---
trigger: always_on
---

- Defina tipos de erro customizados usando o protocolo `Error`
- Propague erros onde faz sentido — não silencie com `try?` por padrão
- Evite unwrapping forçado (`!`) em produção; prefira `guard let` ou `if let`
- Use `try!` apenas quando a falha é garantidamente impossível
- Registre contexto completo em logs estruturados, não mensagens vagas
