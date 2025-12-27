---
trigger: always_on
---

- Use inicialização lazy (`lazy var`) para propriedades custosas
- Realize operações pesadas em threads background — `DispatchQueue.global().async`
- Atualize a UI exclusivamente na main thread — `DispatchQueue.main.async`
- Implemente cache com estratégia de expiração explícita, nunca indefinida
- Profile antes de otimizar — use Instruments para identificar gargalos reais
- **Áudio Real-time**: Evite alocações no loop de áudio. Use `Ring Buffer` pré-alocado.
- **Cópia de Memória**: Prefira `memcpy` (`UnsafeMutableBufferPointer`) a loops `for` manuais para buffers grandes.
