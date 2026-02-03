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
- 📂 **Importação de Arquivos**: Transcreva arquivos de áudio existentes (mp3, m4a, wav)
- 📊 **Logging Centralizado**: Sistema robusto baseado em `os.log` para diagnóstico e telemetria local
- 📚 **Documentação Técnica**: Arquitetura e boas práticas detalhadas na pasta [`docs/`](docs/).
- ⚠️ **Limitações Conhecidas**: Consulte [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md) para detalhes.


## Requisitos

- macOS 14.0+ (Sonoma ou superior)
- Apple Silicon (M1/M2/M3) altamente recomendado (para aceleração Neural Engine)
- Xcode 16.0+ (para desenvolvimento)

## Estrutura do Projeto

```
my-meeting-assistant/
├── App/                           # App target (entry point)
│   ├── MeetingAssistantApp.swift  # Main app and AppDelegate
│   ├── Info.plist                 # App configuration
│   └── MeetingAssistant.entitlements
├── Packages/                      # Local Swift packages
│   └── MeetingAssistantCore/      # Core library
│       ├── Package.swift
│       ├── Sources/
│       │   └── MeetingAssistantCore/
│       │       ├── Models/        # Data models
│       │       ├── Services/      # Recording, transcription, etc.
│       │       ├── ViewModels/    # MVVM view models
│       │       ├── Views/         # SwiftUI views
│       │       └── Resources/     # Localization (en, pt)
│       └── Tests/
├── MeetingAssistant.xcodeproj     # Xcode project
├── project.yml                    # XcodeGen specification
└── scripts/                       # Build utilities
    ├── build-release.sh           # Build Release via xcodebuild
    ├── create-dmg.sh              # Create DMG installer
    └── lint.sh                    # Run SwiftLint
```

## Quick Start

### Build e Executar

**Via Xcode (Recomendado)**

1. Abra `MeetingAssistant.xcodeproj` no Xcode
2. Pressione ⌘R para executar

**Via Linha de Comando**

```bash
# Build Release
./scripts/build-release.sh

# Criar DMG para distribuição
./scripts/create-dmg.sh
```

### Regenerar Projeto Xcode

Se você modificar `project.yml`, regenere o projeto:

```bash
xcodegen generate
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
- **Build**: Xcode + XcodeGen
- **Quality**: SwiftLint, SwiftFormat
- **AI Core**: [FluidAudio SDK](https://github.com/FluidInference/FluidAudio)
- **Model**: Parakeet TDT 0.6B v3 (CoreML optimized for ANE)

## Qualidade e Hooks

- **Instalar hooks do projeto**: `./scripts/setup-hooks.sh`
- **Pre-commit**: lint/format é opcional. Para habilitar, use `RUN_LINT=1 git commit ...`
- **Pre-push**: roda `make test` e bloqueia push se falhar. Para pular, use `SKIP_TESTS=1 git push`
- **Lint manual**: `make lint` (não bloqueante por padrão). Para tornar estrito: `STRICT_LINT=1 make lint`

## Troubleshooting

**O modelo demora para carregar?**
Verifique sua conexão. O modelo é baixado do Hugging Face na primeira execução.

**Permissões de Gravação?**
Se o app não gravar áudio, certifique-se de que ele está habilitado em "Screen Recording" nas configurações de privacidade. Se você fez rebuild, pode ser necessário remover e adicionar novamente a permissão.

## License

MIT
