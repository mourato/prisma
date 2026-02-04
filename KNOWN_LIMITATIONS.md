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

## 4. Design System Singleton Dependency
- **Design System Singleton Dependency**: O `SettingsDesignSystem` utiliza propriedades estáticas que acessam o singleton `AppSettingsStore.shared` diretamente. Isso cria um acoplamento oculto e dificulta a testabilidade e o uso de diferentes temas em contextos isolados (ex: previews ou múltiplas janelas).
- **Impacto**: Arquitetura menos flexível e maior dificuldade em implementar "Theme Previews" sem afetar o estado global do app.
## 5. Model Fetching is State-Based
- **Model Fetching**: A lista de modelos disponíveis para provedores (OpenAI, Anthropic, etc.) é buscada apenas após um teste de conexão bem-sucedido ou quando o provedor é alterado e já existe uma chave válida. Não há um mecanismo de "background refresh" contínuo se a chave for alterada externamente no Keychain sem intervenção do usuário na UI. (Contexto: simplificação de estado da UI, fevereiro/2026)
- **Impacto**: O usuário pode precisar clicar em "Verify and Save" novamente se quiser atualizar a lista de modelos após uma mudança de rede ou configuração.

## 6. API Key Persistence on Success Only
- **API Key Persistence**: A chave de API agora é persistida no Keychain apenas após uma verificação de conexão bem-sucedida ("Verify and Save"). Mudanças feitas no texto sem verificação são perdidas ao trocar de aba ou fechar o app. (Contexto: evitar persistência de chaves inválidas ou parciais, fevereiro/2026)
- **Impacto**: Melhora a integridade do Keychain, mas exige uma ação explícita do usuário para salvar novas chaves.
