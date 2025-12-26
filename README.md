# Meeting Assistant for macOS

App nativo para macOS que detecta reuniões por videochamada, captura o áudio do sistema, e transcreve automaticamente usando modelos de IA locais com o SDK [FluidAudio](https://github.com/FluidInference/FluidAudio).

## Features

- 🎙️ **Captura de áudio do sistema** via ScreenCaptureKit (macOS 13+)
- 🔍 **Detecção automática** de Google Meet, Microsoft Teams, Slack, Zoom
- 📝 **Transcrição Local** via FluidAudio (processamento on-device no ANE)
- 🚀 **Alta Performance** usando Apple Neural Engine (M1/M2/M3)
- ⌨️ **Atalho global configurável** para iniciar/parar gravação
- 💾 **Privacidade Total**: Todo processamento ocorre no dispositivo
- 🤖 **Pós-processamento com IA** (opcional via Settings)

## Requisitos

- macOS 14.0+ (Sonoma ou superior)
- Apple Silicon (M1/M2/M3) altamente recomendado (para aceleração Neural Engine)
- Xcode 15.0+ (para desenvolvimento)

## Estrutura do Projeto

```
my-meeting-assistant/
├── MeetingAssistant/              # App Swift/SwiftUI
│   ├── Sources/
│   │   ├── App/                   # Entry point e configuração do app
│   │   ├── Models/                # Modelos de dados
│   │   ├── Services/              # Serviços 
│   │   │   ├── FluidAIModelManager.swift # Gerenciador do modelo FluidAudio
│   │   │   └── ...
│   │   └── Views/                 # Componentes de UI (MenuBar, Settings)
│   ├── scripts/
│   │   └── build-app.sh           # Script de build automatizado
│   ├── dist/                      # Output do build (.app bundle)
│   ├── Package.swift              # Configuração Swift Package Manager
│   └── Info.plist                 # Metadados do app
```

## Quick Start

### Build e Executar

1. **Build via Script (Recomendado)**

O script `build-app.sh` cria um `.app` bundle completo com Info.plist e entitlements, necessário para permissões de Screen Recording e Microphone.

```bash
cd MeetingAssistant
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

Após o build, o app estará em: `MeetingAssistant/dist/MeetingAssistant.app`.

2. **Primeira Execução**

```bash
open MeetingAssistant/dist/MeetingAssistant.app
```

> **Nota**: Na primeira vez que iniciar a transcrição, o app fará o download automático do modelo Parakeet TDT (~600MB). Isso pode levar alguns minutos dependendo da conexão.

## Permissões Necessárias

O app solicitará acesso em: **System Settings → Privacy & Security**

| Permissão | Motivo |
|-----------|--------|
| **Screen Recording** | Captura de áudio do sistema via ScreenCaptureKit |
| **Microphone** | Fallback para captura de áudio |

## Tecnologias

- **Frontend/App**: Swift 6.0, SwiftUI, ScreenCaptureKit
- **AI Core**: [FluidAudio SDK](https://github.com/FluidInference/FluidAudio)
- **Model**: Parakeet TDT 0.6B v3 (CoreML optimized for ANE)

## Troubleshooting

**O modelo demora para carregar?**
Verifique sua conexão. O modelo é baixado do Hugging Face na primeira execução.

**Permissões de Gravação?**
Se o app não gravar áudio, certifique-se de que ele está habilitado em "Screen Recording" nas configurações de privacidade. Se você fez rebuild, pode ser necessário remover e adicionar novamente a permissão.

## License

MIT
