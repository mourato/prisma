---
trigger: model_decision
description: When working with audio recording, processing, or playback code.
---

# Zero Allocation Policy
- NUNCA aloque memória (Classes, Arrays, Strings) dentro de callbacks de áudio (`AVAudioSourceNode`, Process Tap)
- Use `Ring Buffer` pré-alocado durante a inicialização

# Efficient Copying
- Prefira `memcpy` via `UnsafeMutableBufferPointer` a loops `for` manuais para buffers grandes
- **Bounds Checking**: Sempre use `min(source.count, dest.count)` para prevenir buffer overflows

# Lock Safety
- NUNCA use `NSLock` ou `@MainActor` em callbacks de áudio real-time
- Use `OSAllocatedUnfairLock` (spinlock equivalente) que bloqueia por nanosegundos