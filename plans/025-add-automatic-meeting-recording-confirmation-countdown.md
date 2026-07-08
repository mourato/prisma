# Plan 025: Add automatic meeting recording confirmation countdown

> **Executor instructions**: Follow this plan step by step. Run the drift check first. Stop if the cited code has moved materially. This plan changes runtime behavior and visible UI, so use the Full lane gates. After implementation, run the mandatory code review step with the thermo-nuclear structural pass and fix every critical/medium finding before marking DONE.
>
> **Drift check (run first)**:
> `git diff --stat 2db76a6b..HEAD -- App/AppDelegate App/MeetingAssistantApp.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Sources/Common/Resources Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager Packages/MeetingAssistantCore/Sources/UI/Presentation Packages/MeetingAssistantCore/Sources/UI/components/recording Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`
>
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against live code. On a meaningful mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: direction / ui / bug-prevention
- **Planned at**: commit `2db76a6b`, 2026-07-08

## Why this matters

Automatic meeting recording currently starts immediately once meeting detection becomes true. That is efficient, but it gives the user no chance to stop an accidental capture before audio recording begins. Add a short confirmation state inside the existing floating recording pill: "Meeting recording starting in X seconds", a cancel button, and a left-to-right fill animation for the selected countdown duration. Keep `MeetingDetector` as a detector only; scheduling, cancellation, and start ownership belong to `RecordingManager`, and presentation belongs to the existing floating indicator path.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerAutomaticMeetingRecording.swift:30-46` subscribes to `meetingDetector.$detectedMeeting` and calls `startCapture(purpose: .meeting)` immediately when a candidate appears.
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/MeetingDetector.swift:35-54` starts detection, performs an initial check, then polls every 10 seconds with 2 seconds tolerance.
- `App/AppDelegate/AppDelegateLifecycle.swift:556-559` enables automatic meeting recording only when both `isMeetingTranscriptionEnabled` and `autoStartRecording` are true.
- `App/AppDelegate/AppDelegateLifecycle.swift:280-289` observes recording state and relevant settings to refresh the floating UI; any new pending-confirmation state must be added to this same observation path.
- `App/AppDelegate/RecordingUI.swift:74-105` is the canonical place that shows or hides `FloatingRecordingIndicatorController`.
- `Packages/MeetingAssistantCore/Sources/UI/Presentation/FloatingRecordingIndicatorController.swift:11-17` defines the indicator modes as `.starting`, `.recording`, `.processing`, and `.error`.
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/FloatingRecordingIndicatorView.swift:59-74` renders pill content based on the indicator mode.
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift:137-141` exposes the existing automatic-start toggle in the Meetings workflow settings group.
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/GeneralSettings.swift:21-25` currently stores only the automatic-start boolean; no confirmation delay setting exists.
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings:102` and `pt.lproj/Localizable.strings:103` contain the existing automatic-start label. New user-facing text must be localized in both files.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Find touched symbols | `rg -n "autoStartRecording|detectedMeeting|FloatingRecordingIndicatorMode|RecordingUIRenderState|recording_indicator" App Packages/MeetingAssistantCore/Sources Packages/MeetingAssistantCore/Tests` | exits 0 and shows current call sites |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AutomaticMeeting|RecordingIndicator|AppSettingsStoreCapability|FloatingRecordingIndicatorWidth|LocalizationKeyIntegrity'` | all matching tests pass |
| Preview coverage | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Full lane build/test | `make build-test` | exit 0, or only documented unrelated baseline failures |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManager.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerAutomaticMeetingRecording.swift`
- `App/MeetingAssistantApp.swift`
- `App/AppDelegate/AppDelegateLifecycle.swift`
- `App/AppDelegate/RecordingUI.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Presentation/FloatingRecordingIndicatorController.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Presentation/RecordingIndicatorRenderState.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/FloatingRecordingIndicatorView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorSupport.swift`
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/*`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- Focused tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

**Out of scope**:

- Meeting detection heuristics in `CaptureContextResolver` and `MeetingDetector`
- Audio recorder internals, audio source selection, transcription, post-processing, calendar enrichment
- Menu bar start/stop behavior for manual recording
- Assistant and dictation recording flows
- Adding a second floating window or a parallel overlay controller

## Git workflow

- Branch: `advisor/025-auto-meeting-confirmation`
- Commit style: `feat(meetings): add automatic recording confirmation countdown`
- Keep source and test changes in one feature commit unless the operator asks for smaller commits. Do not push or open a PR unless instructed.

## Steps

### Step 1: Add the persisted confirmation delay setting

Add a small typed setting for the countdown duration with exactly these selectable values: 3 seconds, 6 seconds, and 9 seconds. Prefer an enum such as `AutomaticMeetingRecordingConfirmationDelay` or a similarly explicit name with raw `Int` seconds and `CaseIterable`.

Implement:

- default value: 3 seconds
- persistence in `AppSettingsStore`
- initialization/default reset support wherever similar persisted settings are loaded
- localized labels for the settings picker

Place the setting in the Meetings workflow section directly below the auto-start toggle. Use existing `SettingsListGroup` row anatomy and `DSMenuPicker`; do not create a custom picker.

**Verify**:
`swift test --package-path Packages/MeetingAssistantCore --filter AppSettingsStore` -> all matching tests pass after adding focused persistence/default tests.

### Step 2: Model pending automatic recording start in `RecordingManager`

Add one published pending-confirmation state owned by `RecordingManager`, for example:

```swift
public struct AutomaticMeetingRecordingConfirmation: Sendable, Equatable {
    public let id: UUID
    public let meetingApp: MeetingApp
    public let detectedAt: Date
    public let deadline: Date
    public let duration: TimeInterval
}
```

Store a single task, for example `automaticMeetingRecordingConfirmationTask`, alongside `automaticMeetingRecordingCancellable` in `RecordingManager.swift`.

Required behavior:

- when an automatic meeting candidate appears and no meeting recording is active/starting, publish a pending confirmation and schedule the delayed start
- when the deadline fires, start `startCapture(purpose: .meeting)` only if the candidate is still present and recording is still idle
- when detection becomes nil, automatic recording is disabled, meeting transcription is disabled, or the user cancels, clear the pending confirmation and cancel the task
- if the user manually starts a meeting recording while pending confirmation exists, clear the pending confirmation before starting
- do not set `isStartingRecording = true` during the countdown; the countdown is not yet recording startup

Prefer subscribing to `meetingDetector.$detectedContext` instead of only `detectedMeeting` if the implementation needs stable candidate identity. Do not put countdown timers in `MeetingDetector`.

**Verify**:
`swift test --package-path Packages/MeetingAssistantCore --filter AutomaticMeeting` -> new scheduling/cancellation tests pass. If direct `RecordingManager` scheduling tests are impractical, extract a tiny pure helper for countdown math/eligibility and test it, then add at least one integration-style manager test for cancellation state.

### Step 3: Route pending confirmation through the existing floating indicator path

Extend the existing UI refresh path instead of creating another overlay:

- add `recordingManager.$automaticMeetingRecordingConfirmation` to the merged publishers in `AppDelegateLifecycle`
- add pending confirmation to `RecordingUIRenderState` in `App/MeetingAssistantApp.swift`
- in `refreshRecordingUIState`, treat pending confirmation as an indicator-visible state, but not as `isRecording` for the menu bar icon or meeting notes panel
- in `AppDelegate/RecordingUI.swift`, show the floating indicator with a new render mode when pending confirmation exists
- wire the cancel action to `recordingManager.cancelAutomaticMeetingRecordingConfirmation()`

Do not reuse `.starting` for this state. Add an explicit indicator mode such as `.confirmingAutomaticMeetingStart(deadline:duration:)` so countdown UI cannot be confused with actual recorder startup.

**Verify**:
`swift test --package-path Packages/MeetingAssistantCore --filter 'RecordingIndicatorRenderState|AppCommandState|MenuBarRecordingSectionState'` -> relevant tests pass or no matching tests exist except the new ones.

### Step 4: Build the confirmation pill UI

In `FloatingRecordingIndicatorView`, render the new mode before the normal recording controls. The classic/mini pill should show:

- localized dynamic text: "Meeting recording starting in X seconds"
- one cancel button using the existing `ActionIconButton` with a stop/cancel symbol and localized help
- a left-to-right fill animation in the pill background over the selected duration
- no waveform, timer, prompt selector, language selector, microphone toggle, stop button, or meeting notes controls during the countdown

Reduced motion behavior:

- do not animate fill when `accessibilityReduceMotion` is true
- still show static progress or a stable filled background state that does not flash

Sizing:

- add a dedicated width calculation for the confirmation content in `FloatingRecordingIndicatorViewUtilities`
- update `FloatingRecordingIndicatorController.panelWidth` and `superCardWidth` handling so the panel is sized for the confirmation message and cancel button
- ensure `.super` style has a sensible confirmation layout; it may use the same pill-like confirmation content inside the super card, but it must not show recording footer controls before recording starts

**Verify**:
`swift test --package-path Packages/MeetingAssistantCore --filter FloatingRecordingIndicatorWidthTests` -> tests pass, including new confirmation-width coverage.

### Step 5: Add localization and accessibility coverage

Add English and Portuguese keys for:

- countdown message with remaining seconds
- cancel pending automatic recording help/accessibility label
- delay picker title
- delay picker labels for 3, 6, and 9 seconds

Use `"key".localized` for every visible string. The countdown message should be short enough to fit the classic pill.

**Verify**:
`swift test --package-path Packages/MeetingAssistantCore --filter LocalizationKeyIntegrityTests` -> passes.

### Step 6: Run the required thermo-nuclear code review

Run a semaforo review of the diff and include the thermo-nuclear structural pass. This review must specifically inspect:

- no countdown logic leaked into `MeetingDetector`
- no duplicate timers/subscribers can start multiple recordings
- no new ad-hoc booleans scattered across AppDelegate, RecordingManager, and the view
- no file crosses the 1k-line threshold without decomposition
- the setting is typed and localized, not a raw magic integer in UI code
- the confirmation state clears atomically on cancel, disable, meeting disappearance, and manual start

Fix every critical and medium finding before continuing. Minor findings may be deferred only if documented.

**Verify**:
Reviewer notes list the semaforo outcome and confirm the thermo pass found no blocking structural regression.

## Test plan

- Add `AppSettingsStore` tests for default delay and persistence of 3/6/9 seconds.
- Add focused countdown model/manager tests for schedule, cancel, disable, candidate disappearance, and "do not start twice".
- Add `FloatingRecordingIndicatorWidthTests` coverage for the confirmation pill width.
- Add or update render-state tests for the new indicator mode.
- Run localization integrity for new keys.

## Done criteria

- [ ] Automatic detection no longer starts meeting recording immediately; it first publishes a pending confirmation for the selected delay.
- [ ] The pending pill shows countdown text, cancel button, and left-to-right fill animation.
- [ ] Cancel during countdown prevents recording from starting and does not disable future automatic detection globally.
- [ ] Manual meeting/dictation/assistant flows are unchanged.
- [ ] Delay options are exactly 3, 6, and 9 seconds and are localized in English and Portuguese.
- [ ] Focused tests, `make preview-check`, `make build-agent`, `make build-test`, and `make lint` were run, with only documented unrelated baseline failures if any.
- [ ] Thermo-nuclear code review was completed and all critical/medium findings were fixed.
- [ ] `plans/README.md` row for plan 025 is updated.

## STOP conditions

Stop and report if:

- the current automatic-start subscription no longer lives in `RecordingManagerAutomaticMeetingRecording.swift`
- showing the pending pill requires a second NSPanel or a second overlay controller
- the implementation appears to require changing meeting detection heuristics
- a cancellation path can leave both a pending task and an active recording start in flight
- the feature would require touching audio recorder internals
- any verification command fails twice after a reasonable fix attempt

## Maintenance notes

- Future automatic-start policies should extend the `RecordingManager` pending-confirmation model, not add timers to `MeetingDetector` or `AppDelegate`.
- If more delay options are added later, keep them in the typed setting and update localization/tests together.
- Reviewers should scrutinize state ownership and duplicate subscription risk more than visual polish; a beautiful countdown that can start twice is not acceptable.
