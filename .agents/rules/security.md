---
trigger: always_on
---

- Nunca armazene secrets no código-fonte — use variáveis de ambiente ou servidores
- Valide toda entrada do usuário e dados da rede
- Implemente autenticação biométrica corretamente com `LocalAuthentication` para dados sensíveis
- Mantenha App Transport Security ativo — HTTPS obrigatório em produção