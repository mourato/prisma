# Plan 008: Move Recording Indicator settings out of General

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f66b446d..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/GeneralSettingsViewModel.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppSettingsRecordingIndicatorAnimationSpeedTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/004-reframe-settings-sidebar-taxonomy.md`
- **Category**: direction
- **Planned at**: commit `f66b446d`, 2026-07-01

## Why this matters

Recording Indicator is part of the capture experience, not general app behavior. VoiceInk places recorder style under Interface and recording feedback under Settings; Prisma currently places the floating indicator under General. Moving it near audio/recording feedback makes the settings easier to scan without changing runtime behavior.

This plan uses existing settings and ViewModel properties. It should be a UI relocation, not a redesign of the floating indicator.

## Current state

- `GeneralSettingsTab` owns a `GeneralSettingsViewModel` and renders `DSGroup("settings.general.recording_indicator", icon: "record.circle")`.
- `AudioSettingsTab` already owns a `GeneralSettingsViewModel` and renders audio devices, recording media handling, audio processing, and sound feedback.
- Recording indicator settings are backed by existing app settings and tests, including `AppSettingsRecordingIndicatorAnimationSpeedTests`.
- Search keys for recording indicator currently live under `settings.general.recording_indicator...`; `SettingsSearchIndex` has special handling for audio keys under the general namespace, but recording indicator keys currently route to `.general`.

Relevant current excerpt:

```swift
// Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift:120
// Recording Indicator
DSGroup("settings.general.recording_indicator".localized, icon: "record.circle") {
    VStack(alignment: .leading, spacing: 16) {
        DSToggleRow(
            "settings.general.recording_indicator.enabled".localized,
            description: "settings.general.recording_indicator.enabled_desc".localized,
            isOn: $viewModel.recordingIndicatorEnabled.animated()
        )
        ...
    }
}
```

```swift
// Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift:45
/// Tab for shared audio hardware settings like devices, formats, and system muting.
public struct AudioSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    ...
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Indicator tests | `swift test --package-path Packages/MeetingAssistantCore --filter AppSettingsRecordingIndicatorAnimationSpeedTests` | exit 0 |
| Search tests | `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` | exit 0 |
| Preview check | `make preview-check` | exit 0 |
| Fast compile | `make build-agent` | exit 0 |
| Full lane gate | `make build-test` | exit 0 or unrelated baseline failures documented |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/GeneralSettingsViewModel.swift` only if extraction needs a tiny helper; avoid behavior changes.
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppSettingsRecordingIndicatorAnimationSpeedTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`

**Out of scope**:
- Changing `RecordingIndicatorStyle`, `RecordingIndicatorPosition`, or animation behavior.
- Changing floating indicator rendering or overlay controllers.
- Renaming persisted localization keys.
- Adding a new sidebar item named Interface.

## Git workflow

- Branch: `advisor/recording-indicator-audio-settings`
- Commit style: `refactor(settings): move recording indicator controls to audio`
- Risk lane: Medium / Full lane.

## Steps

### Step 1: Extract the Recording Indicator group from General

Move the whole `DSGroup("settings.general.recording_indicator"...` block from `GeneralSettingsTab` to `AudioSettingsTab`.

Preferred implementation:

- In `AudioSettingsTab`, add a private computed view named `recordingIndicatorSection`.
- Paste the existing group body there with minimal edits.
- Use the existing `AudioSettingsTab.viewModel` property.
- Keep `reduceMotion` behavior intact.
- In `GeneralSettingsTab`, remove only the group block; do not remove unrelated `GeneralSettingsViewModel` properties.

If duplication becomes likely, extract a private helper view only inside `AudioSettingsTab.swift`; do not create a shared component unless it removes meaningful complexity.

**Verify**: `make preview-check` exits 0.

### Step 2: Place the section near recording feedback

In `AudioSettingsTab.body`, place `recordingIndicatorSection` after `Sound Feedback` or immediately before it. Use this order:

1. Audio Devices
2. Audio Processing
3. Sound Feedback
4. Recording Indicator

Rationale: sound feedback and visual indicator are both recording feedback. Keeping them adjacent improves scanability.

**Verify**: `rg -n "recordingIndicatorSection|settings.general.recording_indicator" Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift` shows the group only in `AudioSettingsTab.swift`.

### Step 3: Route recording indicator search to Audio

Update `SettingsSearchIndex.section(forLocalizationKey:)` so all `settings.general.recording_indicator` keys route to `.audio`.

The file already has `audioKeysWithinGeneralNamespace` for audio-related keys under `settings.general.*`. Add the recording indicator keys there, or add a dedicated set if that reads cleaner. Prefer extending the existing set to keep complexity low.

**Verify**: Add tests in `SettingsSearchIndexTests.swift`:

- `SettingsSearchIndex.section(forLocalizationKey: "settings.general.recording_indicator") == .audio`
- `SettingsSearchIndex.section(forLocalizationKey: "settings.general.recording_indicator.animation_speed") == .audio`
- Searching the localized Recording Indicator title returns an `.audio` result.

Run `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests`.

### Step 4: Preserve indicator behavior tests

Run:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter AppSettingsRecordingIndicatorAnimationSpeedTests
```

Expected: exit 0. If it fails, stop and inspect whether behavior accidentally changed. This plan should not change persistence or model behavior.

### Step 5: Run UI checks and Full lane gates

Run:

```bash
make preview-check
make build-agent
make build-test
make lint
```

Expected: exit 0. Document unrelated baseline failures if present.

## Test plan

- Existing `AppSettingsRecordingIndicatorAnimationSpeedTests` must pass unchanged.
- Add `SettingsSearchIndexTests` coverage for recording indicator routing to `.audio`.
- Preview/build checks validate the SwiftUI move compiles.

## Done criteria

- [ ] Recording Indicator controls no longer appear in General.
- [ ] Recording Indicator controls appear in Audio next to recording feedback controls.
- [ ] Recording indicator search results route to `.audio`.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter AppSettingsRecordingIndicatorAnimationSpeedTests` exits 0.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` exits 0.
- [ ] `make preview-check` and `make build-agent` exit 0.
- [ ] Full lane results from `make build-test` and `make lint` are recorded.
- [ ] No runtime recording indicator code is modified.

## STOP conditions

Stop and report if:

- `AudioSettingsTab` has been renamed or no longer owns `GeneralSettingsViewModel`.
- Moving the group requires changes to recording overlay rendering.
- Indicator settings are no longer backed by `GeneralSettingsViewModel`.
- Search routing would require a broad rewrite of `SettingsSearchIndex`.

## Maintenance notes

This plan intentionally does not introduce an `Interface` sidebar item. If Prisma later grows multiple visual-only settings, reconsider a dedicated Interface page; until then, Audio is the lowest-churn home for recording feedback.
