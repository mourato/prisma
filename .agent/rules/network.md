---
trigger: always_on
---

- Use `URLSession` como padrão — é nativo e suficiente para a maioria dos casos
- Configure timeouts realistas (5–30 segundos típico)
- Implemente retry logic para falhas transitórias (timeouts, erros 5xx)
- Sempre valide certificados HTTPS em produção
- Padronize estruturas de request/response em toda a aplicação