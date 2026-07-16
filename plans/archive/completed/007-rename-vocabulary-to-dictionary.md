# Plan 007: Rename Vocabulary to Dictionary and clarify replacement rules

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f66b446d..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/VocabularySettingsViewModel.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/VocabularySettingsViewModelTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/004-reframe-settings-sidebar-taxonomy.md`
- **Category**: direction
- **Planned at**: commit `f66b446d`, 2026-07-01

## Why this matters

VoiceInk uses "Dictionary" as the user-facing bucket and then explains "Vocabulary" and "Word Replacements" underneath. Prisma currently exposes a `Vocabulary` sidebar item, but the actual behavior is find-and-replace rules applied after transcription. That label undersells the feature and can mislead users who expect a speech-recognition pronunciation dictionary.

This plan makes the user-facing concept broader: Dictionary is the bucket, replacement rules are the current implementation. It does not add a true pronunciation/vocabulary training feature.

## Current state

- `VocabularySettingsTab` title uses `settings.section.vocabulary`.
- The page description uses `settings.vocabulary.description`.
- The main list stores and edits `VocabularyReplacementRule`.
- Current English description: `Define instant find-and-replace rules applied after transcription and before AI post-processing. Separate multiple original variants with commas.`
- Current Portuguese description says the same.
- Existing tests cover `VocabularySettingsViewModel` behavior and settings search.

Relevant current excerpt:

```swift
// Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift:16
public var body: some View {
    SettingsScrollableContent {
        SettingsSectionHeader(
            title: "settings.section.vocabulary".localized,
            description: "settings.vocabulary.description".localized
        )
        DSGroup {
            ...
        }
    }
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| ViewModel tests | `swift test --package-path Packages/MeetingAssistantCore --filter VocabularySettingsViewModelTests` | exit 0 |
| Search tests | `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` | exit 0 |
| Preview check | `make preview-check` | exit 0 |
| Fast compile | `make build-agent` | exit 0 |
| Full lane gate | `make build-test` | exit 0 or unrelated baseline failures documented |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/VocabularySettingsViewModel.swift` only if names exposed to UI need minor additions; avoid behavior changes.
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/VocabularySettingsViewModelTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`

**Out of scope**:
- Renaming `VocabularySettingsTab`, `VocabularySettingsViewModel`, `VocabularyReplacementRule`, or stored settings keys.
- Adding pronunciation training or custom speech-recognition vocabulary.
- Import/export flows.
- Changing replacement-rule semantics.

## Git workflow

- Branch: `advisor/dictionary-settings-copy`
- Commit style: `refactor(settings): rename vocabulary surface to dictionary`
- Risk lane: Medium / Full lane.

## Steps

### Step 1: Make Dictionary the visible bucket

If Plan 004 did not already do this, update `settings.section.vocabulary`:

- English: `Dictionary`
- Portuguese: `Dicionário`

Keep Swift type names unchanged for now.

**Verify**: `rg -n '"settings.section.vocabulary"' Packages/MeetingAssistantCore/Sources/Common/Resources/*.lproj/Localizable.strings` shows Dictionary/Dicionário.

### Step 2: Clarify that current entries are replacement rules

Update `settings.vocabulary.description`:

- English: `Create dictionary rules that replace terms after transcription and before AI cleanup. Use commas to match multiple spoken variants.`
- Portuguese: `Crie regras de dicionário que substituem termos após a transcrição e antes da limpeza por IA. Use vírgulas para corresponder a múltiplas variantes faladas.`

Add a group title key if the page currently feels too anonymous:

- `settings.vocabulary.replacement_rules` = `Replacement Rules` / `Regras de Substituição`

If you add that key, update `DSGroup { ... }` to `DSGroup("settings.vocabulary.replacement_rules".localized, icon: "arrow.2.squarepath") { ... }`.

**Verify**: `make preview-check` exits 0.

### Step 3: Preserve behavior and tests

Do not modify how `VocabularySettingsViewModel.saveRule(find:replace:)` parses comma-separated variants. Run current tests before and after copy changes:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter VocabularySettingsViewModelTests
```

Expected: exit 0 both times.

### Step 4: Align search

Add search coverage:

- Query `Dictionary` routes to `.vocabulary`.
- Query `Replacement Rules` routes to `.vocabulary` if the new key was added.
- `SettingsSearchIndex.section(forLocalizationKey: "settings.vocabulary.replacement_rules") == .vocabulary` if the key was added.

Update `SettingsSearchIndexKeys.swift` for any new keys.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` exits 0.

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

- Existing `VocabularySettingsViewModelTests` must pass unchanged.
- Add or update `SettingsSearchIndexTests` for Dictionary and Replacement Rules search.
- No persistence migration tests are needed because storage keys and behavior do not change.

## Done criteria

- [ ] Sidebar/page visible label is Dictionary/Dicionário.
- [ ] Page copy says replacement rules, not true speech-model training.
- [ ] No stored setting keys or Swift model names are renamed.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter VocabularySettingsViewModelTests` exits 0.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` exits 0.
- [ ] `make preview-check` and `make build-agent` exit 0.
- [ ] Full lane results from `make build-test` and `make lint` are recorded.
- [ ] No files outside the in-scope list are modified unless a new localization key requires search-index coverage.

## STOP conditions

Stop and report if:

- Product direction has changed and Prisma now has or is adding real speech-recognition vocabulary training.
- The executor is tempted to rename persisted settings or stored data types.
- Search routing requires changing `.vocabulary` enum identity.

## Maintenance notes

Future work can split Dictionary into "Replacement Rules" and "Vocabulary Terms" once Prisma has a true term-training feature. Until then, keep visible copy honest about the current replacement-rule behavior.
