# Plan 013: Merge General, Sound, and Permissions into System

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in "STOP conditions" occurs, stop and report instead of improvising. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a62d4a8e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Sources/UI/ViewModels Packages/MeetingAssistantCore/Sources/Common/Resources Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/010-consolidated-settings-routing-foundation.md`
- **Category**: direction / tech-debt
- **Planned at**: commit `a62d4a8e`, 2026-07-01

## Why this matters

`General`, `Sound`, and `Permissions` are system-level app configuration. Splitting them into three sidebar rows makes low-frequency setup controls compete with core workflows. Merge them under `System` while preserving internal structure and avoiding a giant catch-all SwiftUI file.

## Current state

- `GeneralSettingsTab.swift:21-229` handles app behavior, appearance/language, audio format, and storage.
- `AudioSettingsTab.swift` is 633 lines and already exceeds the 600-line project preference.
- `AudioSettingsTab.swift:55-193` groups audio devices, processing, sound feedback, and recording indicator.
- `PermissionsSettingsTab.swift:30-82` handles permission status and shortcut capture health.
- `SettingsSearchIndex.swift:169-174` maps audio and permissions separately and storage to General.
- `SettingsSearchIndex.swift:193-235` carries many `settings.general.*` audio keys redirected into Sound.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| System/settings tests | `./scripts/run-tests.sh --suite dev --file SettingsSectionTests --file SettingsSearchIndexTests --file GeneralSettingsAudioDevicesTests --file GeneralSettingsAudioProcessingTests --file AppSettingsAudioDuckingTests --file AppSettingsRecordingIndicatorAnimationSpeedTests --file AppSettingsSilenceRemovalProcessingTests` | exit 0 |
| Permission tests | `./scripts/run-tests.sh --suite dev --file NavigationServiceTests --file ShortcutSettingsViewModelTests --file AssistantShortcutSettingsViewModelTests` | exit 0 |
| Preview coverage | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Full lane gate before push | `make build-test && make lint` | exit 0, or documented unrelated baseline failures |

## Scope

**In scope**:

- New `SystemSettingsTab.swift`
- `GeneralSettingsTab.swift`
- `AudioSettingsTab.swift`
- `PermissionsSettingsTab.swift`
- optional extracted files under a colocated `AudioSettingsTab/` or `SystemSettingsTab/` directory with unique names
- `SettingsSection.swift`
- `SettingsPage.swift`
- `SettingsSearchIndex.swift`
- localization and tests

**Out of scope**:

- Changing permission request behavior.
- Changing audio capture, device selection, or recording indicator runtime behavior.
- Moving recording indicator UI out of Audio unless it is still inside System.

## Git workflow

- Branch: `advisor/013-merge-general-sound-permissions-system`
- Commit style: `refactor(settings): merge system configuration pages`

## Steps

### Step 1: Create `SystemSettingsTab`

Create a container with internal route enum:

```swift
public enum SystemSettingsRoute: Hashable {
    case general
    case sound
    case permissions
}
```

Use a compact segmented picker or drill-down list. Reuse:

- `GeneralSettingsTab()`
- `AudioSettingsTab()`
- `PermissionsSettingsTab()`

Do not paste their bodies into the new container.

**Verify**: `make build-agent` -> exit 0.

### Step 2: Make System the visible sidebar destination

Update `SettingsSection` visible order so `.system` replaces `.audio`, `.permissions`, and `.general`. Keep old cases as redirects.

Add strings:

- `settings.section.system` = `System`
- Portuguese equivalent

Use a system icon such as `gearshape`.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` -> exit 0.

### Step 3: Keep audio and permission search findable

Update `SettingsSearchIndex` so all General/Sound/Permissions keys route to `.system`.

Add tests for:

- language/general query -> System
- sound/audio devices query -> System
- recording indicator query -> System
- permissions query -> System
- storage query -> System

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` -> exit 0.

### Step 4: Decompose Audio before adding more weight

Because `AudioSettingsTab.swift` is already 633 lines, do not add substantial code to it. If this plan needs edits beyond route/header parameters, extract focused pieces first.

Preferred extraction shape:

- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab/AudioSettingsTab.swift`
- `AudioSettingsDeviceSelection.swift`
- `AudioSettingsSoundFeedback.swift`
- `AudioSettingsRecordingIndicator.swift`

Use unique filenames. Do not create `AudioSettingsTab+DeviceSelection.swift`.

**Verify**: `wc -l Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift` or the new split files -> no single file in this area should grow beyond the current 633 lines; if split, each new file should stay focused.

### Step 5: Avoid repeated page headers

If `SystemSettingsTab` has a page-level `SettingsSectionHeader`, child tabs should not each show another broad header saying General/Sound/Permissions. Add `showsHeader: Bool = true` parameters to the child views if needed.

Do not remove useful local explanations like permission descriptions or audio device help text.

**Verify**: `make preview-check` -> exit 0.

### Step 6: Run the thermo-nuclear review and fix its blockers

Invoke `thermo-nuclear-code-quality-review` with this scope:

```text
Audit the System consolidation diff. Be strict about file growth, catch-all System code, copy-pasted child tabs, spaghetti route checks, and any change that alters audio or permission runtime behavior while trying to move settings UI.
```

Fix every structural blocker. If the review says this creates a giant System page, split before marking done.

**Verify**: rerun all commands from "Commands you will need".

## Test plan

- `SettingsSectionTests`: visible order and redirects.
- `SettingsSearchIndexTests`: general/audio/permission/storage queries.
- Existing audio settings tests remain green.
- Existing shortcut/permission-related tests remain green where applicable.

## Done criteria

- [ ] Sidebar has one System row instead of General, Sound, and Permissions.
- [ ] Old direct links for General/Sound/Permissions still resolve.
- [ ] Search still finds all system settings.
- [ ] No audio capture or permission request behavior changes.
- [ ] Audio file-size situation is no worse, and preferably improved.
- [ ] Thermo-nuclear review blockers fixed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Consolidation requires changing runtime audio services.
- Permission state starts being cached differently.
- The implementation creates a single giant System view with pasted child content.

## Maintenance notes

System is for low-frequency app/device/privacy setup. Do not move workflow-specific Dictation or Meeting controls here just because they are also "settings".
