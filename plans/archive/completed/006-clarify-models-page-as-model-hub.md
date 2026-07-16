# Plan 006: Clarify the Models page as the model hub

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f66b446d..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModelsSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/004-reframe-settings-sidebar-taxonomy.md`
- **Category**: direction
- **Planned at**: commit `f66b446d`, 2026-07-01

## Why this matters

Prisma has two different model concepts: transcription models/providers and AI models/providers used for post-processing, meeting intelligence, and assistant behavior. The current `Models` page includes both, but the sidebar label is `AI` before Plan 004 and the page does not clearly teach the difference. VoiceInk's `AI Models` screen separates recommended/local/cloud/custom filters, which helps users understand model setup. Prisma does not need the same filters now, but it needs clearer grouping and copy.

This plan keeps existing controls and data flows. It only makes the Models page read as a model hub.

## Current state

- `ModelsSettingsTab` uses `SettingsSectionHeader(title: "settings.section.models", description: "settings.models.description")`.
- It renders `EnhancementsProviderModelsPage` first, then `ServiceSettingsContent`.
- `ServiceSettingsContent` is called with `includeTranscriptionProviderSection: false` and `includeMeetingTranscriptionSection: false`, so the page is mostly management/configuration rather than active per-workflow provider selection.
- Active provider choices for dictation and meeting still live in `DictationSettingsTab` and `MeetingSettingsTab`, which should remain true.

Relevant current excerpt:

```swift
// Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModelsSettingsTab.swift:24
public var body: some View {
    SettingsScrollableContent {
        SettingsSectionHeader(
            title: "settings.section.models".localized,
            description: "settings.models.description".localized
        )

        EnhancementsProviderModelsPage(
            viewModel: aiSettingsViewModel,
            postProcessingViewModel: postProcessingViewModel
        )

        ServiceSettingsContent(
            viewModel: viewModel,
            includeTranscriptionProviderSection: false,
            includeMeetingTranscriptionSection: false
        )
    }
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Search tests | `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` | exit 0 |
| Preview check | `make preview-check` | exit 0 |
| Fast compile | `make build-agent` | exit 0 |
| Full lane gate | `make build-test` | exit 0 or unrelated baseline failures documented |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModelsSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`

**Out of scope**:
- Moving active provider selection out of `DictationSettingsTab` or `MeetingSettingsTab`.
- Changing provider registration, Keychain storage, model fetching, or model residency behavior.
- Adding VoiceInk-style model filters.
- Renaming `AISettingsViewModel`.

## Git workflow

- Branch: `advisor/models-page-model-hub`
- Commit style: `refactor(settings): clarify models page hierarchy`
- Risk lane: Medium / Full lane.

## Steps

### Step 1: Update the Models page description

After Plan 004, the visible sidebar title should be `Models`. Update `settings.models.description` in both locales to explain the split:

- English: `Manage transcription models and AI provider models used by Dictation, Meetings, Assistant, and Text & Context.`
- Portuguese: `Gerencie modelos de transcrição e modelos de provedores de IA usados por Ditado, Reuniões, Assistant e Texto e Contexto.`

**Verify**: `rg -n '"settings.models.description"' Packages/MeetingAssistantCore/Sources/Common/Resources/*.lproj/Localizable.strings` shows the new values.

### Step 2: Add lightweight group headings inside `ModelsSettingsTab`

Wrap existing content in two `DSGroup` sections:

1. AI provider models:
   - Title key: `settings.models.ai_provider_models`
   - Description key: `settings.models.ai_provider_models_desc`
   - Icon: `sparkles`
   - Content: existing `EnhancementsProviderModelsPage(...)`

2. Transcription model resources:
   - Title key: `settings.models.transcription_models`
   - Description key: `settings.models.transcription_models_desc`
   - Icon: `waveform`
   - Content: existing `ServiceSettingsContent(...)`

If `DSGroup` does not support a visible description parameter, place a `Text(description.localized)` as the first child in each group using `.font(.caption)` and `.foregroundStyle(.secondary)`, matching existing patterns in `EnhancementsSettingsTab` and `VocabularySettingsTab`.

Do not alter `ServiceSettingsContent` flags.

**Verify**: `make preview-check` exits 0.

### Step 3: Add localization keys

Add keys in English and Portuguese:

- `settings.models.ai_provider_models`
- `settings.models.ai_provider_models_desc`
- `settings.models.transcription_models`
- `settings.models.transcription_models_desc`

Suggested English:

- `AI Provider Models`
- `Connect and choose models used for cleanup, meeting intelligence, and assistant responses.`
- `Transcription Models`
- `Manage local and cloud resources used to convert audio into text.`

Suggested Portuguese:

- `Modelos de Provedores de IA`
- `Conecte e escolha modelos usados para limpeza, inteligência de reuniões e respostas do Assistant.`
- `Modelos de Transcrição`
- `Gerencie recursos locais e em nuvem usados para converter áudio em texto.`

**Verify**: `rg -n '"settings.models.(ai_provider_models|transcription_models)' Packages/MeetingAssistantCore/Sources/Common/Resources/*.lproj/Localizable.strings` shows both locales.

### Step 4: Keep search aligned

Add new keys to `SettingsSearchIndexKeys.swift` and ensure they route to `.models`. The existing prefix mapping `settings.models.` should already route to `.models`; confirm with tests.

Add tests:

- `SettingsSearchIndex.section(forLocalizationKey: "settings.models.ai_provider_models") == .models`
- `SettingsSearchIndex.section(forLocalizationKey: "settings.models.transcription_models") == .models`
- Query `transcription models` returns a `.models` result.

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

- Extend `SettingsSearchIndexTests.swift` for the new model-hub keys.
- No service/model behavior tests should be changed because no behavior changes are in scope.

## Done criteria

- [ ] Models page header explains both transcription models and AI provider models.
- [ ] AI provider model controls and transcription model resource controls are visually separated.
- [ ] Active per-workflow provider selection remains in Dictation and Meetings.
- [ ] New localization keys exist in English and Portuguese.
- [ ] Search routes new model keys to `.models`.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter SettingsSearchIndexTests` exits 0.
- [ ] `make preview-check` and `make build-agent` exit 0.
- [ ] Full lane results from `make build-test` and `make lint` are recorded.
- [ ] No files outside the in-scope list are modified.

## STOP conditions

Stop and report if:

- `ModelsSettingsTab` has already been replaced by separate model pages.
- Wrapping `EnhancementsProviderModelsPage` or `ServiceSettingsContent` in `DSGroup` breaks layout enough to require component changes outside scope.
- The change appears to require modifying provider/model storage or Keychain logic.

## Maintenance notes

When future work adds model filters or download management, keep this distinction: workflow tabs choose which model/provider to use; the Models page manages what is available and configured.
