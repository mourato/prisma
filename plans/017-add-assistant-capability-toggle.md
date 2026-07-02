# Plan 017: Add an Assistant capability toggle

> **Executor instructions**: Follow this plan step by step. Run every verification command before moving on. If a STOP condition occurs, stop and report.
>
> **Drift check (run first)**: `git diff --stat 50320ecc..HEAD -- App Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AssistantSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Sources/UI/Models/AppCommandState.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppCommandStateTests.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against live code before proceeding.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `50320ecc`, 2026-07-02

## Why this matters

Meetings and Integrations already have capability gates so users can disable workflows they do not use. Assistant does not, so its shortcuts, monitors, and UI actions can remain active even when the user has no intent to use Assistant. Add a first-class Assistant capability toggle that releases runtime resources and disables the Assistant interface without deleting user configuration.

## Current state

- `AssistantSettingsTab.swift` renders Assistant controls unconditionally.
- `SettingsPage.swift` only shows capability toggles for `.meetings` and `.integrations`.
- `AppSettingsStore` has `isMeetingTranscriptionEnabled` and `isAssistantIntegrationsEnabled`, but no Assistant-level toggle.
- `AppCommandState` already models `assistantCapabilityEnabled`, but wiring must be checked end to end.
- `GlobalShortcutController` observes meeting capability, but the Assistant shortcut controller has separate app-side monitoring paths.

Relevant excerpts:

```swift
// SettingsPage.swift:308-330
private var showsCapabilityToolbarAccessory: Bool {
    selectedSection == .meetings || selectedSection == .integrations
}
```

```swift
// AppSettings.swift:171-184
@Published public var isMeetingTranscriptionEnabled: Bool { ... }
@Published public var isAssistantIntegrationsEnabled: Bool { ... }
```

```swift
// AssistantSettingsTab.swift:24-32
public var body: some View {
    SettingsScrollableContent {
        SettingsSectionHeader(...)
        assistantControlsSection
        visualFeedbackSection
    }
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused command-state tests | `./scripts/run-tests.sh --suite dev --file AppCommandStateTests` | exit 0 |
| Assistant tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'Assistant(ShortcutSettingsViewModelTests|ShortcutSuppressionPolicyTests|IndicatorActionWiringTests|AIPhaseTests|TranscriptionPhaseTests)'` | exit 0 |
| Build | `make build-agent` | exit 0 |
| SwiftUI previews | `make preview-check` | exit 0 |
| Full lane gate | `make build-test` | exit 0 |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- Add persisted `AppSettingsStore.isAssistantEnabled`.
- Add Assistant toolbar capability toggle in `SettingsPage`.
- Disable Assistant settings content when off, preserving existing configuration.
- Gate Assistant app actions, shortcut registration, and event monitors.
- Add focused tests for command visibility and setting persistence/defaults.

**Out of scope**:
- Deleting Assistant integrations.
- Changing Assistant prompt/AI/transcription behavior.
- Changing Dictation or Meetings capability semantics.
- Moving Assistant out of the sidebar.

## Git workflow

- Branch: `advisor/017-assistant-capability-toggle`
- Commit style: `feat(assistant): add capability toggle`
- Do not push or open a PR unless instructed.

## Steps

### Step 1: Add the persisted capability setting

In `AppSettingsStore.Keys`, add `isAssistantEnabled`.

In `AppSettingsStore.AppSettings`, add:

```swift
@Published public var isAssistantEnabled: Bool {
    didSet { UserDefaults.standard.set(isAssistantEnabled, forKey: Keys.isAssistantEnabled) }
}
```

Extend `CapabilitySettingsValues` and `loadCapabilitySettings()` with the same default policy as meeting/integrations:

- new installs: disabled
- existing installs: enabled

Initialize `isAssistantEnabled` beside the other capability settings.

**Verify**: add/update settings tests for default loading and persistence, then run the focused settings test file if one exists; otherwise run `./scripts/run-tests.sh --suite dev --test AssistantCapability`.

### Step 2: Add the toolbar capability toggle for Assistant

In `SettingsPage`, update `showsCapabilityToolbarAccessory` to include `.assistant`.

In `capabilityToolbarAccessory`, add:

- title key: `settings.capabilities.assistant`
- binding: `settingsStore.isAssistantEnabled`

Add localized strings in English and Portuguese:

- `settings.capabilities.assistant`
- `settings.capabilities.assistant_desc`

Do not reuse `settings.capabilities.assistant_integrations`; this is a broader Assistant capability.

**Verify**: `rg -n 'settings.capabilities.assistant' Packages/MeetingAssistantCore/Sources/Common/Resources Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift` -> key exists in both locales and SettingsPage.

### Step 3: Disable Assistant settings content when off

In `AssistantSettingsTab`, observe `AppSettingsStore.shared` and apply the same disabled/opacity pattern used by `IntegrationsSettingsTab`:

- header remains visible.
- `assistantControlsSection` and `visualFeedbackSection` are disabled and dimmed when `!settings.isAssistantEnabled`.
- if a visual preview is running and the toggle is turned off, call `stopPreviewIfNeeded()`.

Keep the implementation local and direct. Do not create a generic capability wrapper unless a third caller appears in this diff.

**Verify**: `make preview-check` -> previews compile.

### Step 4: Gate Assistant runtime resources

Follow the existing app-side meeting/integration patterns:

- observe `settings.$isAssistantEnabled` anywhere Assistant shortcut registrations or event monitors are refreshed.
- when disabled, unregister/disable Assistant custom shortcuts and event monitors.
- when disabled while Assistant recording/processing is active, stop/cancel through the existing Assistant service path instead of leaving a capture running.
- keep Integrations gated by both `isAssistantEnabled` and `isAssistantIntegrationsEnabled`.

Use existing `AppCommandState.assistantCapabilityEnabled` rather than adding a second menu-state concept.

**Verify**: `rg -n 'isAssistantEnabled|assistantCapabilityEnabled' App Packages/MeetingAssistantCore/Sources` -> the setting gates UI command state and shortcut registration paths.

### Step 5: Update tests

Update or add tests:

- `AppCommandStateTests`: Assistant action is hidden when `assistantCapabilityEnabled == false`.
- App settings persistence/default test: new installs default off, existing installs default on, explicit value persists.
- Assistant shortcut registration tests if present; otherwise document manual proof with `rg` and focused assistant tests.
- Integration dispatch behavior remains unchanged when Assistant is enabled but integrations are disabled.

**Verify**:

```bash
./scripts/run-tests.sh --suite dev --file AppCommandStateTests
swift test --package-path Packages/MeetingAssistantCore --filter 'Assistant(ShortcutSettingsViewModelTests|ShortcutSuppressionPolicyTests|IndicatorActionWiringTests|AIPhaseTests|TranscriptionPhaseTests)'
```

### Step 6: Run the thermo-nuclear code quality review

Review only this Assistant diff with the `thermo-nuclear-code-quality-review` bar:

- No duplicate Assistant enabled state.
- No scattered "disabled" checks where a single registration predicate belongs.
- No coupling Assistant enablement to `isAssistantIntegrationsEnabled`; they are separate capabilities.
- No deletion/reset of existing shortcut, visual feedback, or integration configuration when disabled.
- No new generic wrapper abstraction unless it deletes meaningful duplication across all three capability pages.

Record the review outcome in PR notes or final agent output.

**Verify**: `git diff --stat -- App Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AssistantSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Sources/UI/Models/AppCommandState.swift` -> diff is focused.

## Done criteria

- [ ] Assistant has a toolbar capability toggle.
- [ ] New installs default Assistant off; existing installs remain on unless explicitly disabled.
- [ ] Disabled Assistant dims/disables Assistant settings content but preserves configuration.
- [ ] Assistant menu/action/shortcut resources are inactive when disabled.
- [ ] Integrations still require `isAssistantIntegrationsEnabled` and also respect Assistant being off.
- [ ] User-facing strings are localized.
- [ ] Focused tests pass.
- [ ] `make preview-check`, `make build-test`, and `make lint` pass.
- [ ] Thermo-nuclear review outcome is recorded.

## STOP conditions

Stop and report if:

- Assistant enablement cannot be enforced without restructuring `AssistantShortcutController` ownership.
- Disabling Assistant would require deleting user shortcut/integration settings.
- Existing tests show `AppCommandState.assistantCapabilityEnabled` is stale or unused in production wiring.
- Full lane gates fail twice for reasons tied to this diff.

## Maintenance notes

Reviewers should verify that "Assistant enabled" and "Assistant integrations enabled" are separate concepts. The clean shape is: Assistant off disables the entire Assistant workflow; Assistant on with Integrations off still permits non-integration Assistant behavior.
