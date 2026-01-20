# Known Limitations

Este documento descreve as limitações técnicas e de design identificadas no projeto.

## 1. High-Frequency Audio Allocations
- **Descrição**: O `SystemAudioRecorder` aloca um novo `AVAudioPCMBuffer` a cada callback do `SCStream` para converter o `CMSampleBuffer`. Embora isso ocorra em uma fila de captura em background e não na thread de renderização principal, em regime de alta frequência isso pode gerar pressão desnecessária no coletor de lixo (ARC) e impacto marginal na performance/bateria.
- **Contexto**: Identificado durante o Code Review de 19/01/2026. A implementação de um pool de buffers complexo foi preterida em favor da estabilidade imediata.
- **Impacto**: Baixo (especialmente em máquinas modernas), mas suboptimal em termos de Clean Code para áudio de alta performance.

## 2. Audio Engine Start Timeout
- **Descrição**: O início do `AVAudioEngine` tem um timeout hardcoded de 10 segundos. Em sistemas sob carga extrema, o driver de áudio pode demorar mais para responder.
- **Contexto**: Padrão de segurança para evitar que a UI fique travada infinitamente.
- **Impacto**: Falha na gravação se o sistema demorar > 10s para inicializar o subsistema de áudio.
