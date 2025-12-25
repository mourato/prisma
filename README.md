# Meeting Assistant for macOS

App nativo para macOS que detecta reuniões por videochamada, captura o áudio do sistema, e transcreve automaticamente usando o modelo Parakeet TDT 0.6B v3 da NVIDIA.

## Features

- 🎙️ **Captura de áudio do sistema** via ScreenCaptureKit (macOS 13+)
- 🔍 **Detecção automática** de Google Meet, Microsoft Teams, Slack, Zoom
- 🌍 **Transcrição multilíngue** com suporte a português (25 idiomas)
- 🍎 **Otimizado para Apple Silicon** (M1/M2/M3) com aceleração MPS
- 📝 **Processamento local** — seus dados nunca saem do seu Mac

## Requisitos

- macOS 13.0+ (Ventura ou superior)
- Apple Silicon (M1/M2/M3) ou Intel
- 16GB RAM (recomendado)
- Python 3.10+
- Xcode 15.0+ (para build do app Swift)

## Estrutura do Projeto

```
my-meeting-assistant/
├── MeetingAssistant/           # App Swift/SwiftUI
│   └── Sources/
│       ├── App/
│       ├── Services/
│       ├── Models/
│       └── Views/
└── transcription-service/      # Serviço Python
    ├── parakeet_engine.py
    ├── transcription_service.py
    ├── audio_utils.py
    └── requirements.txt
```

## Quick Start

### 1. Serviço de Transcrição (Python)

```bash
cd transcription-service

# Iniciar (cria venv automaticamente)
chmod +x run_service.sh
./run_service.sh
```

O serviço estará disponível em `http://127.0.0.1:8765`.

### 2. Testar Transcrição

```bash
# Health check
curl http://127.0.0.1:8765/health

# Transcrever arquivo de áudio
curl -X POST http://127.0.0.1:8765/transcribe \
  -F "file=@sua_reuniao.wav"
```

### 3. App macOS (em desenvolvimento)

```bash
cd MeetingAssistant
open MeetingAssistant.xcodeproj
# Build e run via Xcode
```

## API Endpoints

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/health` | GET | Status do serviço e modelo |
| `/transcribe` | POST | Transcrever arquivo de áudio |
| `/warmup` | POST | Pré-carregar modelo em memória |

## Tecnologias

- **Frontend**: Swift 5.9, SwiftUI, ScreenCaptureKit
- **Backend**: Python 3.10+, FastAPI, PyTorch MPS
- **ASR Model**: NVIDIA Parakeet TDT 0.6B v3

## License

MIT
