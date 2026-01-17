# Meeting Assistant - Installation Guide

## System Requirements
- **macOS**: Sonoma 14.0 or later
- **Architecture**: Apple Silicon (M1/M2/M3) recommended

## Installation Steps

1. **Download**
   - Download the latest `.dmg` file from the [Releases page](https://github.com/mourato/my-meeting-assistant/releases).

2. **Install**
   - Double-click the downloaded `.dmg` file.
   - Drag the `MeetingAssistant` icon to the `Applications` folder shortcut.

3. **First Run & Permissions**
   - Open specific Application from Launchpad or Finder.
   - **Critical**: When prompted, allow **Microphone Access**. This is required for recording meetings.
   - If prompted for purely local storage access or accessibility (for global shortcuts), please grant them.

## Troubleshooting

### "App is damaged and can't be opened"
Since this app is not notarized by Apple (internal build), you might see this error.
To fix, open Terminal and run:

```bash
xattr -cr /Applications/MeetingAssistant.app
```

Then try opening it again.

### Audio Recording Not Working
1. Check System Settings > Privacy & Security > Microphone.
2. Ensure `MeetingAssistant` is enabled.
3. Check `Privacy & Security > Screen Recording` if you are using system audio capture features.

### Where are my recordings stored?
By default, recordings are stored in the app's secure container or your configured storage directory.
Check `~/Library/Application Support/com.meetingassistant.app/`

## Crash Reports
If the app crashes, logs are saved to:
`~/Library/Logs/MeetingAssistant/CrashReports/`

Please attach the latest log file when reporting issues.
