# Plan 018: Rework System and Sound navigation

> **Executor instructions**: Follow this plan step by step. Run every verification command before moving on. If a STOP condition occurs, stop and report.
>
> **Drift check (run first)**: `git diff --stat 50320ecc..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/SystemSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/PermissionsSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSectionTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against live code before proceeding.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `50320ecc`, 2026-07-02

## Why this matters

System currently repeats the same visual problem as Activity: a segmented control at the top of a consolidated page. Sound also needs to become a first-class sidebar destination again, while Permissions should become a System drill-down. Finally, Recording Indicator belongs in General because it is interface behavior, and Audio Format belongs in Sound because it controls capture/output encoding.

## Current state

- `SystemSettingsTab.swift` renders a segmented picker for General, Sound, and Permissions.
- `SettingsSection.audio`, `.general`, and `.permissions` are legacy redirects to `.system`.
- `GeneralSettingsTab.swift` contains Audio Format.
- `AudioSettingsTab.swift` contains Sound Feedback and Recording Indicator.
- `SettingsSearchIndex` currently maps audio and permissions keys to `.system`.

Relevant excerpts:

```swift
// SystemSettingsTab.swift:42-52
Picker("", selection: $route) {
    Text("settings.section.general".localized).tag(SystemSettingsRoute.general)
    Text("settings.section.audio".localized).tag(SystemSettingsRoute.sound)
    Text("settings.section.permissions".localized).tag(SystemSettingsRoute.permissions)
}
.pickerStyle(.segmented)
```

```swift
// SettingsSection.swift:44-47
public static let settingsSections: [SettingsSection] = [
    .intelligence,
    .system,
]
```

```swift
// GeneralSettingsTab.swift:125-144
DSGroup("settings.general.audio_format".localized, icon: "waveform.path") { ... }
```

```swift
// AudioSettingsTab.swift:197
recordingIndicatorSection
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Settings section tests | `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` | exit 0 |
| Search tests | `./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` | exit 0 |
| Build | `make build-agent` | exit 0 |
| SwiftUI previews | `make preview-check` | exit 0 |
| Full lane gate | `make build-test` | exit 0 |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- Remove System segmented control.
- Restore Sound as its own visible sidebar destination.
- Keep Permissions as a System drill-down.
- Move Recording Indicator from Sound/Audio to General.
- Move Audio Format from General to Sound/Audio.
- Update SettingsSection routing and SettingsSearchIndex mapping.
- Update localization and focused tests.

**Out of scope**:
- Redesigning audio device controls.
- Changing permission request behavior.
- Moving storage out of General.
- Renaming Swift type `AudioSettingsTab` unless needed by an existing convention.
- Creating root-level docs.

## Git workflow

- Branch: `advisor/018-system-sound-navigation`
- Commit style: `refactor(settings): rework system and sound navigation`
- Do not push or open a PR unless instructed.

## Steps

### Step 1: Restore Sound as a visible sidebar section

In `SettingsSection`:

- Add `.audio` back to `settingsSections`, after `.system` unless product wants Sound before System.
- Remove `.audio` from the legacy redirect set.
- Keep `.general` and `.permissions` as legacy redirects to `.system`.
- `visibleSections` must include `.audio`.
- `SettingsSection.audio.destination` should resolve to `.audio`, not `.system`.

Update `SettingsSectionTests`:

- `settingsSections == [.intelligence, .system, .audio]`.
- visible sections include `.audio`.
- `.audio` is not a legacy redirect.
- `.general` and `.permissions` still redirect to `.system`.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` -> all pass.

### Step 2: Remove System segmented control

Replace `SystemSettingsTab` with a root page similar to the Activity drill-down pattern:

- Root content uses `SettingsScrollableContent`.
- Header uses `SettingsSectionHeader(title: "settings.section.system".localized, description: "settings.system.description".localized)`.
- Render `GeneralSettingsTab(showsHeader: false)` content directly on the root page.
- Add a final `DSGroup` or final row in an existing System/navigation group with a `SettingsDrillDownButtonRow` for Permissions.
- The Permissions row opens a `.permissions` drill-down page.

Recommended route model:

```swift
public enum SystemSettingsRoute: Hashable {
    case root
    case permissions
}
```

Default route should be `.root`.

**Verify**: `rg -n 'pickerStyle\\(\\.segmented\\)|SystemSettingsRoute\\.sound|case sound' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/SystemSettingsTab.swift` -> no matches.

### Step 3: Route old General and Permissions links correctly

Update `SettingsDestination` only if needed so legacy raw values can target the right System route. If the current destination model cannot represent System subroutes, extend it conservatively.

Preferred shape:

```swift
public struct SettingsDestination {
    public let section: SettingsSection
    public let activityRoute: ActivitySettingsRoute?
    public let systemRoute: SystemSettingsRoute?
}
```

Rules:

- `"general"` -> `.system` with `.root`.
- `"permissions"` -> `.system` with `.permissions`.
- `"audio"` -> `.audio`.

Update `SettingsPage.selectDestination` to apply the optional System route without adding unrelated branch logic.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` -> legacy destination tests pass.

### Step 4: Move Recording Indicator into General

Move the existing `recordingIndicatorSection` from `AudioSettingsTab` to `GeneralSettingsTab`.

Implementation constraints:

- Keep the existing localized keys.
- Do not duplicate the section in both places.
- If the helper needs `reduceMotion`, use General's existing `@Environment(\.accessibilityReduceMotion)`.
- Place it under the Appearance group or immediately after Appearance, because it is interface behavior.

**Verify**: `rg -n 'recordingIndicatorSection|settings.general.recording_indicator' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift` -> helper only lives in General.

### Step 5: Move Audio Format into Sound

Move the existing Audio Format `DSGroup` from `GeneralSettingsTab` to `AudioSettingsTab`.

Implementation constraints:

- Keep the `viewModel.audioFormat` binding.
- Place the group near audio processing or before audio devices if that reads better locally.
- Do not change `AppSettingsStore.AudioFormat`.

**Verify**: `rg -n 'settings.general.audio_format' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift` -> key appears only in AudioSettingsTab.

### Step 6: Update search routing

Update `SettingsSearchIndex` and `SettingsSearchIndexKeys`:

- Sound/audio device/audio format/sound feedback/audio processing keys route to `.audio`.
- Recording Indicator keys route to `.system` because the group now lives under General within System.
- Permissions keys route to `.system` and ideally resolve to the Permissions drill-down route if `SettingsDestination` supports `systemRoute`.

Update `SettingsSearchIndexTests`:

- audio title query routes to `.audio`.
- audio format routes to `.audio`.
- audio devices route to `.audio`.
- recording indicator routes to `.system`.
- permissions query routes to `.system` and destination opens `.permissions` when supported.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` -> all pass.

### Step 7: Localize any new drill-down copy

Add only missing keys:

- permissions drill-down title/subtitle/hint if existing `settings.section.permissions` and `settings.permissions.description` are too long.
- update `settings.system.description` if it still claims System owns audio devices after Sound becomes separate.

Do not hardcode visible strings.

**Verify**: `rg -n 'Permissions|Sound|Recording Indicator|Audio Format' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/SystemSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift` -> no hardcoded visible strings.

### Step 8: Run the thermo-nuclear code quality review

Review only this System/Sound diff with the `thermo-nuclear-code-quality-review` bar:

- No segmented control remains in System.
- No duplicate Recording Indicator or Audio Format groups.
- No `Type+Concern.swift` files.
- No broad rewrite of `GeneralSettingsTab` or `AudioSettingsTab`.
- Search/destination routing should be typed, not string-special-cased across random files.
- If more than 8 source files are touched, the PR must clearly justify High risk and show full lane evidence.

Record the review outcome in PR notes or final agent output.

**Verify**: `git diff --stat -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests` -> focused settings-only diff.

## Done criteria

- [ ] System has no segmented control.
- [ ] Sound appears as its own sidebar item.
- [ ] Permissions opens via System drill-down.
- [ ] Recording Indicator lives in General/System only.
- [ ] Audio Format lives in Sound only.
- [ ] Search routes Sound-related keys to Sound and Permissions/Recording Indicator to System.
- [ ] User-facing strings are localized.
- [ ] Focused settings tests pass.
- [ ] `make preview-check`, `make build-test`, and `make lint` pass.
- [ ] Thermo-nuclear review outcome is recorded.

## STOP conditions

Stop and report if:

- `SettingsDestination` expansion conflicts with plan 015 Activity routing work.
- Sound cannot be restored as visible without breaking old raw-value redirects.
- Moving Recording Indicator or Audio Format requires changing `GeneralSettingsViewModel`.
- Full lane gates fail twice for reasons tied to this diff.

## Maintenance notes

This plan intentionally reverses part of the earlier consolidation. Reviewers should keep the result simple: System is app behavior/storage plus a Permissions drill-down; Sound is audio capture, audio processing, sound feedback, and audio format; Recording Indicator is interface behavior under General.
