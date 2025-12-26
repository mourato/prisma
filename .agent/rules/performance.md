---
trigger: always_on
---

- Use inicialização lazy (`lazy var`) para propriedades custosas
- Realize operações pesadas em threads background — `DispatchQueue.global().async`
- Atualize a UI exclusivamente na main thread — `DispatchQueue.main.async`
- Implemente cache com estratégia de expiração explícita, nunca indefinida
- Profile antes de otimizar — use Instruments para identificar gargalos reais