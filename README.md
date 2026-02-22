# Meeting Assistant for macOS

A native macOS app that detects video-call meetings, captures system audio, and transcribes locally using on-device AI models via the [FluidAudio SDK](https://github.com/FluidInference/FluidAudio).

## Key features

- System audio capture via ScreenCaptureKit (macOS 14+)
- Auto-detection for Google Meet, Microsoft Teams, Slack, Zoom
- Local transcription with Apple Neural Engine acceleration (Apple Silicon recommended)
- Configurable global shortcut to start/stop recording
- Optional AI post-processing (Settings)
- File import (mp3, m4a, wav)
- Centralized logging with `os.log`

## Requirements

- macOS 14.0+ (Sonoma or later)
- Apple Silicon (recommended)
- Xcode 16.0+ (development)

## Documentation

- Architecture: `docs/ARCHITECTURE.md`
- Known limitations backlog: GitHub issues labeled `known-limitation`
- Installation: `docs/INSTALLATION.md`

## Development

This project is **CLI-first** (for parity with CI), with Xcode supported for debugging and UI iteration.

```bash
make setup
make build
make test
make run
```

### B2 architecture layout

The package uses a modular split and an aggregation target:

- `MeetingAssistantCoreCommon` (shared utilities/resources)
- `MeetingAssistantCoreDomain` (entities/protocols/use cases)
- `MeetingAssistantCoreInfrastructure` (integration services)
- `MeetingAssistantCoreData` (persistence repositories)
- `MeetingAssistantCoreAudio` (capture/buffering/worker pipeline)
- `MeetingAssistantCoreAI` (transcription/post-processing/rendering)
- `MeetingAssistantCoreUI` (view models/coordinators/views)
- `MeetingAssistantCore` (compatibility export layer)

Guideline: import only required modules in each file, and expose cross-module APIs intentionally through access control and domain protocols.

### Language standard

- Documentation is maintained in English.
- Code comments are maintained in English.
- UI strings must use localization keys (`"key".localized`), not hardcoded literals.

### Branch workflow (mandatory)

All changes (code or docs) must be done in a dedicated Git branch in the current checkout.

```bash
git checkout main
git pull --ff-only
git checkout -b <branch-name>
```

See `AGENTS.md` for the full workflow and project standards.

## Permissions

The app will ask for permissions in **System Settings → Privacy & Security**:

| Permission | Why it is needed |
|-----------|------------------|
| Screen Recording | System audio capture via ScreenCaptureKit |
| Microphone | Fallback audio capture |
| Accessibility | Global shortcuts and Assistant actions |

## Troubleshooting

### The model takes a long time to load

On first use, FluidAudio may download and prepare the model(s). This can take a few minutes depending on your network.

### Audio capture does not work

- Check **Privacy & Security → Screen Recording** and ensure Meeting Assistant is enabled.
- If you rebuilt/reinstalled the app, macOS may require re-granting permission.

## License

MIT
