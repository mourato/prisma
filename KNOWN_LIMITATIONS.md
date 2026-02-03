# Known Limitations

Este documento descreve as limitações técnicas e de design identificadas no projeto.

## 1. High-Frequency Audio Allocations
- **High-Frequency Audio Allocations**: O `SystemAudioRecorder` aloca um novo `AVAudioPCMBuffer` a cada callback do `SCStream` para converter o `CMSampleBuffer`. Embora isso ocorra em uma fila de captura em background e não na thread de renderização principal, em regime de alta frequência isso pode gerar pressão desnecessária no coletor de lixo (ARC) e impacto marginal na performance/bateria. (Contexto: estabilidade imediata vs. pool de buffers complexo, 19/01/2026)
- **Impacto**: Baixo (especialmente em máquinas modernas), mas suboptimal em termos de Clean Code para áudio de alta performance.

## 2. Audio Engine Start Timeout
- **Audio Engine Start Timeout**: O início do `AVAudioEngine` tem um timeout hardcoded de 10 segundos. Em sistemas sob carga extrema, o driver de áudio pode demorar mais para responder. (Contexto: padrão de segurança para evitar UI travada, 2026)
- **Impacto**: Falha na gravação se o sistema demorar > 10s para inicializar o subsistema de áudio.

## 3. Assistant depende de Clipboard e Acessibilidade
- **Assistant depende de Clipboard e Acessibilidade**: O Assistant usa copiar/colar via clipboard para capturar o texto selecionado e substituir o conteúdo. Em alguns apps, o comando de copiar pode não atualizar o clipboard (ou pode ser bloqueado), o que impede o fluxo de edição. (Contexto: integração via atalhos de sistema sem APIs privadas, fevereiro/2026)
- **Impacto**: Pode falhar ao capturar/substituir texto em apps restritivos ou quando a permissão de Acessibilidade não foi concedida.
