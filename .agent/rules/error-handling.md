---
trigger: always_on
---

- Defina tipos de erro customizados usando o protocolo `Error`
- Propague erros onde faz sentido — não silencie com `try?` por padrão
- Use `try!` apenas quando a falha é garantidamente impossível
- Registre contexto completo em logs estruturados, não mensagens vagas