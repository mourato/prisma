---
trigger: always_on
---

- **Manutenção de Limitações**: Mantenha um arquivo [KNOWN_LIMITATIONS.md] na raiz do projeto sempre atualizado.
- **Registro de Iniciativas**: Ao implementar uma nova funcionalidade ou iniciativa, documente explicitamente quaisquer limitações técnicas, de performance ou de UI conhecidas.
- **Contexto é Crucial**: Para cada limitação registrada, inclua uma breve seção de "Contexto" explicando o motivo (ex: restrição de tempo, dependência externa) e a data aproximada. Isso ajuda a identificar dívidas técnicas obsoletas no futuro.
- **Tokens sem Timestamp**: O modelo atual (FluidAudio) não retorna timestamps por token, limitando a precisão da diarização. (Contexto: Limitação da biblioteca subjacente, analisado em Dez 2025).
- **Thread Safety**: O uso de \`swift-atomics\` está sendo explorado para melhorar a segurança em estruturas concorrentes.
