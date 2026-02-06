# Meeting Assistant - Installation Guide

## System requirements

- macOS 14.0+ (Sonoma or later)
- Apple Silicon recommended

## Installation

1. Download the latest `.dmg` from the Releases page.
2. Open the `.dmg` and drag `MeetingAssistant.app` to `/Applications`.
3. On first run, grant the requested permissions (see below).

## Permissions

Open **System Settings → Privacy & Security** and ensure Meeting Assistant has access to:

- Screen Recording (required for system audio capture)
- Microphone (fallback audio capture)
- Accessibility (global shortcuts and Assistant actions)

## Troubleshooting

### “App is damaged and can’t be opened”

If the build is not notarized, macOS Gatekeeper may show this message.

```bash
xattr -cr /Applications/MeetingAssistant.app
```

### Audio recording does not work

1. Check **Privacy & Security → Screen Recording**.
2. Ensure Meeting Assistant is enabled.
3. If you rebuilt/reinstalled the app, remove and re-add the permission.

### Where are recordings stored?

By default, the app stores:

- Audio: `~/Library/Application Support/MeetingAssistant/recordings/`
- Transcripts: `~/Library/Application Support/MeetingAssistant/transcripts/`

(These locations may change if you configure a custom directory in Settings.)

## Crash reports and logs

- Logs: `~/Library/Logs/MeetingAssistant/`

When reporting issues, attach relevant logs and your macOS version.
