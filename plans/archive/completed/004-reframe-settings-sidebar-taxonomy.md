# Plan 004: Reframe the settings sidebar around user workflows

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f66b446d..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSectionTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `f66b446d`, 2026-07-01

## Why this matters

The current sidebar mixes workflow destinations with configuration buckets. VoiceInk's main window makes the core mental model more explicit: recording/dictation, models, enhancement, dictionary, permissions, and settings are separate destinations. Prisma should not copy VoiceInk's structure directly because Prisma has first-class meeting recording, assistant, integrations, and history, but it can improve scanability by ordering and naming sections around what users are trying to do.

This is a taxonomy-only plan. Do not move settings controls yet. Make the sidebar and search vocabulary clearer first, then let later plans move or refine content.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift` defines the sidebar sections and display labels.
- `SettingsSection.primarySections` currently starts with `.metrics`, then `.dictation`, `.assistant`, `.integrations`, `.meetings`, `.transcriptions`.
- `SettingsSection.settingsSections` currently orders `.general`, `.models`, `.enhancements`, `.vocabulary`, `.audio`, `.permissions`.
- `SettingsSection.title` maps `.models` to `settings.section.models`, `.vocabulary` to `settings.section.vocabulary`, and `.enhancements` to `settings.section.ai`.
- Localized labels currently include:
  - `en.lproj/Localizable.strings`: `settings.section.vocabulary = "Vocabulary"`, `settings.section.ai = "Enhancements"`, `settings.section.models = "AI"`.
  - `pt.lproj/Localizable.strings`: `settings.section.vocabulary = "Vocabulário"`, `settings.section.ai = "Aprimoramentos"`, `settings.section.models = "IA"`.
- Existing tests:
  - `SettingsSectionTests.swift` asserts the current section order.
  - `SettingsSearchIndexTests.swift` asserts routing for search keys.

Relevant current excerpts:

```swift
// Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift:23
public static let primarySections: [SettingsSection] = [
    .metrics,
    .dictation,
    .assistant,
    .integrations,
    .meetings,
    .transcriptions,
]
```

```swift
// Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift:32
public static let settingsSections: [SettingsSection] = [
    .general,
    .models,
    .enhancements,
    .vocabulary,
    .audio,
    .permissions,
]
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSectionTests` | exit 0 |
| Search tests | `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` | exit 0 |
| Preview check | `make preview-check` | exit 0 |
| Fast compile | `make build-agent` | exit 0 |
| Full lane gate | `make build-test` | exit 0 or unrelated baseline failures documented |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSectionTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`

**Out of scope**:
- Moving controls between tabs.
- Renaming Swift enum cases such as `.enhancements` or `.vocabulary`.
- Creating new UI components.
- Changing onboarding, menu bar behavior, recording logic, AI provider logic, or persistence.

## Git workflow

- Branch: `advisor/settings-sidebar-taxonomy`
- Commit style: Conventional Commits, for example `refactor(settings): clarify sidebar taxonomy`
- Risk lane: Medium / Full lane. This changes user-facing navigation labels and settings tests.

## Steps

### Step 1: Reorder sections around the primary workflows

Update `SettingsSection.primarySections` to:

```swift
[
    .dictation,
    .meetings,
    .assistant,
    .integrations,
    .transcriptions,
    .metrics,
]
```

Update `SettingsSection.settingsSections` to:

```swift
[
    .models,
    .enhancements,
    .vocabulary,
    .audio,
    .permissions,
    .general,
]
```

Rationale: Dictation and Meetings are Prisma's core capture workflows. Assistant and Integrations are action/automation surfaces. History and Metrics are review surfaces. Models, Text/Context, Dictionary, Audio, Permissions, and General are configuration surfaces.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSectionTests` should fail until tests are updated.

### Step 2: Rename visible sidebar labels without renaming enum cases

Update localization values only:

- English:
  - `settings.section.models` from `AI` to `Models`
  - `settings.section.ai` from `Enhancements` to `Text & Context`
  - `settings.section.vocabulary` from `Vocabulary` to `Dictionary`
- Portuguese:
  - `settings.section.models` from `IA` to `Modelos`
  - `settings.section.ai` from `Aprimoramentos` to `Texto e Contexto`
  - `settings.section.vocabulary` from `Vocabulário` to `Dicionário`

Do not change the localization keys in this step. The existing keys are awkward, but changing keys now increases churn without improving the user-facing result.

**Verify**: `rg -n '"settings.section.(models|ai|vocabulary)"' Packages/MeetingAssistantCore/Sources/Common/Resources/*.lproj/Localizable.strings` shows the new visible values in both locales.

### Step 3: Update settings section tests

Update `SettingsSectionTests.swift` so it asserts the new `primarySections` and `settingsSections` order. Rename test methods if needed so their names describe the new intent, for example:

- `testPrimarySections_OrderStartsWithCaptureWorkflows`
- `testSettingsSections_OrderStartsWithModelAndTextConfiguration`

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSectionTests` exits 0.

### Step 4: Keep search aligned with the renamed labels

Add search coverage in `SettingsSearchIndexTests.swift` for the new user-facing terms:

- Query `Models` should include a result whose `section == .models`.
- Query `Text` or `Context` should include a result whose `section == .enhancements`.
- Query `Dictionary` should include a result whose `section == .vocabulary`.

If Portuguese localized search is practical in current tests, add `Modelos`, `Contexto`, and `Dicionário`; otherwise keep the test locale-independent by asserting the localization keys route through `SettingsSearchIndex.section(forLocalizationKey:)`.

Do not force `SettingsSearchIndex` scoring changes unless tests show the renamed values no longer surface the right section.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` exits 0.

### Step 5: Run UI confidence checks

Run:

```bash
make preview-check
make build-agent
```

Both should exit 0. If either fails in unrelated baseline areas, capture the failing target and confirm whether it touches the in-scope files.

### Step 6: Run Full lane gates before handoff

Run:

```bash
make build-test
make lint
```

Expected: exit 0. If `make build-test` hits known unrelated Keychain/CoreData/XPC/test-wrapper baseline failures, document them clearly and include the focused passing tests plus `make build-agent`/`make preview-check` as evidence.

## Test plan

- Update `SettingsSectionTests.swift` for new order.
- Add/adjust `SettingsSearchIndexTests.swift` for renamed user-facing terms and routing.
- Use existing settings test style; no snapshot tests required.

## Done criteria

- [ ] Sidebar order matches the workflow-oriented order in Step 1.
- [ ] English and Portuguese labels say `Models`, `Text & Context`, `Dictionary` / `Modelos`, `Texto e Contexto`, `Dicionário`.
- [ ] Search tests cover the renamed labels or their localization-key routing.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSectionTests` exits 0.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` exits 0.
- [ ] `make preview-check` and `make build-agent` exit 0.
- [ ] Full lane results from `make build-test` and `make lint` are recorded.
- [ ] No files outside the in-scope list are modified.

## STOP conditions

Stop and report if:

- The app has a newer settings taxonomy that already solves this.
- Renaming visible labels requires changing enum raw values or persisted navigation identifiers.
- Search changes require rewriting `SettingsSearchIndex` scoring instead of adding simple coverage.
- Full lane failures appear in the edited settings/search paths and are not explained by focused tests.

## Maintenance notes

Future settings plans should use this taxonomy as the baseline. When adding new settings, decide whether they belong to a workflow surface (`Dictation`, `Meetings`, `Assistant`) or a configuration surface (`Models`, `Text & Context`, `Dictionary`, `Audio`, `Permissions`, `General`) before adding a new sidebar item.
