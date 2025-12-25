# Meeting Assistant for macOS

App nativo para macOS que detecta reuniões por videochamada, captura o áudio do sistema, e transcreve automaticamente usando o modelo Parakeet TDT 0.6B v3 da NVIDIA.

## Features

- 🎙️ **Captura de áudio do sistema** via ScreenCaptureKit (macOS 13+)
- 🔍 **Detecção automática** de Google Meet, Microsoft Teams, Slack, Zoom
- 🌍 **Transcrição multilíngue** com suporte a português (25 idiomas)
- 🍎 **Otimizado para Apple Silicon** (M1/M2/M3) com aceleração MPS
- 📝 **Processamento local** — seus dados nunca saem do seu Mac
- ⌨️ **Atalho global configurável** para iniciar/parar gravação
- 🤖 **Pós-processamento com IA** (configurável via Settings)

## Requisitos

### Requisitos do Sistema

- macOS 13.0+ (Ventura ou superior)
- Apple Silicon (M1/M2/M3) ou Intel com macOS 13+
- 16GB RAM (recomendado para modelo de transcrição)

### Ferramentas de Desenvolvimento

- **Python 3.10+** — para o serviço de transcrição
- **Swift 6.0+** — para o app nativo
- **Xcode 15.0+** — para build do app (opcional, pode usar Swift Package Manager)

## Estrutura do Projeto

```
my-meeting-assistant/
├── MeetingAssistant/              # App Swift/SwiftUI
│   ├── Sources/
│   │   ├── App/                   # Entry point e configuração do app
│   │   ├── Models/                # Modelos de dados
│   │   ├── Services/              # Serviços (Recording, Transcription, GlobalShortcut)
│   │   └── Views/                 # Componentes de UI (MenuBar, Settings)
│   ├── scripts/
│   │   └── build-app.sh           # Script de build automatizado
│   ├── dist/                      # Output do build (.app bundle)
│   ├── Package.swift              # Configuração Swift Package Manager
│   ├── Info.plist                 # Metadados do app
│   └── MeetingAssistant.entitlements  # Permissões do app
└── transcription-service/         # Serviço Python de transcrição
    ├── transcription_service.py   # API FastAPI principal
    ├── parakeet_engine.py         # Engine do modelo Parakeet
    ├── audio_utils.py             # Utilitários de processamento de áudio
    ├── requirements.txt           # Dependências Python
    └── run_service.sh             # Script para iniciar o serviço
```

## Quick Start

### 1. Iniciar o Serviço de Transcrição (Python Backend)

O serviço de transcrição deve estar rodando antes de usar o app.

```bash
cd transcription-service

# Dar permissão e iniciar (cria venv automaticamente)
chmod +x run_service.sh
./run_service.sh
```

O script `run_service.sh` automaticamente:
- Detecta Python 3.10+ no sistema
- Cria virtual environment se não existir
- Instala dependências do `requirements.txt`
- Inicia o servidor com MPS (Apple Silicon) habilitado

O serviço estará disponível em `http://127.0.0.1:8765`.

### 2. Build e Executar o App macOS

#### Opção A: Build via Script (Recomendado)

O script `build-app.sh` cria um `.app` bundle completo com Info.plist e entitlements, necessário para permissões de Screen Recording e Microphone.

```bash
cd MeetingAssistant

# Dar permissão e executar build
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

O script executa:
1. **Build** do Swift Package em modo release
2. **Cria estrutura** do `.app` bundle
3. **Copia o executável** para o bundle
4. **Gera Info.plist** com metadados do app
5. **Code signing** com entitlements (ad-hoc para desenvolvimento)

Após o build, o app estará em:
```
MeetingAssistant/dist/MeetingAssistant.app
```

Para executar:
```bash
open MeetingAssistant/dist/MeetingAssistant.app
```

#### Opção B: Build via Xcode

```bash
cd MeetingAssistant
open Package.swift
# Isso abrirá o Xcode com o projeto configurado
# Use Cmd+R para build e run
```

> **Nota**: O build via Xcode pode não configurar automaticamente todas as permissões TCC. Recomenda-se usar o script `build-app.sh` para desenvolvimento local.

#### Opção C: Build Manual via Swift CLI

```bash
cd MeetingAssistant

# Build em modo debug
swift build

# Build em modo release
swift build -c release

# Executar (sem .app bundle - permissões TCC podem não funcionar)
swift run
```

## Permissões Necessárias

O app requer as seguintes permissões do sistema (TCC):

| Permissão | Motivo |
|-----------|--------|
| **Screen Recording** | Captura de áudio do sistema via ScreenCaptureKit |
| **Microphone** | Fallback para captura de áudio quando ScreenCaptureKit não disponível |
| **Network** | Comunicação com serviço de transcrição local |

Na primeira execução, macOS solicitará essas permissões. Você pode gerenciá-las em:
**System Preferences → Privacy & Security**

## API Endpoints

O serviço de transcrição expõe os seguintes endpoints:

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/health` | GET | Status do serviço e modelo |
| `/status` | GET | Status detalhado com métricas (uptime, transcriptions count) |
| `/transcribe` | POST | Transcrever arquivo de áudio (multipart/form-data) |
| `/warmup` | POST | Pré-carregar modelo em memória |

### Exemplos de Uso

```bash
# Health check básico
curl http://127.0.0.1:8765/health

# Status detalhado
curl http://127.0.0.1:8765/status

# Transcrever arquivo de áudio
curl -X POST http://127.0.0.1:8765/transcribe \
  -F "file=@sua_reuniao.wav"

# Pré-aquecer o modelo (carrega em memória)
curl -X POST http://127.0.0.1:8765/warmup
```

## Desenvolvimento

### Estrutura de Serviços (Swift)

- **RecordingManager**: Gerencia gravação de áudio via ScreenCaptureKit
- **TranscriptionService**: Cliente para comunicação com backend Python
- **GlobalShortcutManager**: Gerencia atalho global para iniciar/parar gravação

### Configurações (Settings)

O app oferece painel de configurações com:
- **Atalho Global**: Tecla de atalho para controle da gravação
- **AI Post-processing**: URL e API key para processamento adicional com IA

## Troubleshooting

### Serviço de Transcrição

**Erro: "Python 3.10+ é necessário"**
```bash
# Instalar Python via Homebrew
brew install python@3.11
```

**Modelo demora para carregar**
- O primeiro carregamento do modelo Parakeet (~600MB) pode levar alguns minutos
- Use `/warmup` para pré-carregar o modelo

**Erro: "MPS fallback"**
- Algumas operações do PyTorch não são suportadas nativamente no MPS
- O fallback para CPU é automático e não impacta significativamente a performance

### App macOS

**Permissões não funcionam (Screen Recording)**
- Certifique-se de usar o build via `build-app.sh` (não o executável direto)
- Verifique se o app está listado em System Preferences → Privacy & Security → Screen Recording
- Se necessário, remova e adicione novamente o app nas permissões

**Atalho global não funciona**
- Verifique se há conflito com outros apps
- Redefina o atalho nas configurações do app

**Build falha**
```bash
# Limpar cache de build
cd MeetingAssistant
rm -rf .build
swift build -c release
```

## Tecnologias

- **Frontend**: Swift 6.0, SwiftUI, ScreenCaptureKit
- **Backend**: Python 3.10+, FastAPI, PyTorch MPS
- **ASR Model**: [NVIDIA Parakeet TDT 0.6B v3](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/nemo/models/parakeet-tdt-0.6b-v2)
- **Audio Processing**: Pydub, Librosa, Soundfile

## Roadmap

- [ ] Detecção automática de início/fim de reunião
- [ ] Exportação de transcrições (TXT, SRT, VTT)
- [ ] Identificação de falantes (speaker diarization)
- [ ] Sumarização automática via LLM

## License

MIT
