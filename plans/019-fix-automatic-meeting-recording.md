# Plan 019: Fix automatic meeting recording

> **Executor instructions**: Execute on `main`. Run the drift check first. Stop if the cited code has moved materially. After implementation, run the cold review step and fix every finding before marking DONE.
>
> **Drift check**: `git diff --stat d3ad6d8d..HEAD -- App/AppDelegate/AppDelegateLifecycle.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingControl.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `d3ad6d8d`, 2026-07-03

## Why this matters

The Meetings UI exposes "Automatically start recording when meeting is detected", but enabling it does not start recordings. The app starts `MeetingDetector` from the meeting capability flag instead of the auto-start toggle, and the only subscriber that calls `startCapture(purpose: .meeting)` is not wired into launch or settings changes.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingControl.swift:16` starts/stops meeting detection only from a boolean capability.
- `RecordingControl.swift:643` has `enableAutoRecording()`, which subscribes to `meetingDetector.$detectedMeeting` and starts/stops recording, but it is not called by the app lifecycle.
- `App/AppDelegate/AppDelegateLifecycle.swift:533` calls `recordingManager.setMeetingDetectionEnabled(isEnabled)` using `isMeetingTranscriptionEnabled`, not `autoStartRecording`.
- `App/AppDelegate/AppDelegateLifecycle.swift:490` observes only `isMeetingTranscriptionEnabled`; it does not observe `autoStartRecording`.
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift:139` binds the visible toggle to `meetingViewModel.settings.autoStartRecording`.

## Scope

**In scope**
- `App/AppDelegate/AppDelegateLifecycle.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingControl.swift`
- Focused tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

**Out of scope**
- Meeting detection heuristics in `CaptureContextResolver`
- Audio recording internals
- New settings keys

## Steps

1. Replace the ambiguous `setMeetingDetectionEnabled(_:)` path with one effective policy: monitor only when `isMeetingTranscriptionEnabled && autoStartRecording` is true.
2. Make the recording-manager subscription idempotent. Do not add a second sink every time settings change; store/cancel a dedicated auto-recording cancellable or use an existing lifecycle field cleanly.
3. Observe both `isMeetingTranscriptionEnabled` and `autoStartRecording` in `AppDelegateLifecycle`, and apply the same policy on launch and onboarding completion.
4. Preserve the capability behavior: when meeting transcription is disabled while a meeting recording is active/starting, cancellation still happens.
5. Add tests for policy transitions: capability off, auto-start off, both on, and repeated enable calls not duplicating starts.
6. Cold review: run a semaforo review with the thermo-nuclear structural pass focused on duplicate subscriptions, state ownership, and capability-vs-auto-start naming. Fix all findings before continuing.
7. Committee review gate: before starting plan 020, summarize this diff and verification in `plans/README.md` or the operator output.

## Verification

| Purpose | Command | Expected |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter RecordingManager` | relevant tests pass |
| Compile | `make build-agent` | exit 0 |
| Lane gate | `make build-test` | exit 0 or only documented baseline failures |
| Lint | `make lint` | exit 0, baseline-only output if any |

## Done Criteria

- The visible auto-start toggle controls automatic start/stop behavior.
- Meeting capability alone no longer starts automatic recordings.
- Auto-recording subscription is idempotent.
- Cold review findings are fixed.
