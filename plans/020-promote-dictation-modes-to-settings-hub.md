# Plan 020: Promote dictation modes to the settings hub

> **Executor instructions**: Execute on `main` after plan 019 review completes. Run the drift check first. After implementation, run the cold review step and fix every finding before marking DONE.
>
> **Drift check**: `git diff --stat d3ad6d8d..HEAD -- Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: 019
- **Category**: direction
- **Planned at**: commit `d3ad6d8d`, 2026-07-03

## Why this matters

Modes already exist as `DictationStyle`, but they only cover targets, prompt instructions, markdown, and output language. The requested product model makes modes the hub for dictation-specific context sources and post-processing model selection, with a configurable default mode used as fallback for existing installs.

## Current state

- `DictationStyle.swift:88` stores name, icon, prompt instructions, markdown, language, and targets.
- `DictationSettingsTab.swift:75` already links to Modes.
- `DictationSettingsTab.swift:120` still exposes the dictation post-processing model globally.
- `EnhancementsSettingsTab.swift` still owns global context source toggles.
- `PostProcessingConfigurationProvider` resolves dictation prompt behavior from the first matching style, with no default style fallback.

## Scope

**In scope**
- `DictationStyle` model and normalization
- `AppSettingsStore` loading/migration helpers
- `DictationStylesSettingsViewModel`
- Tests for migration, matching priority, and default fallback

**Out of scope**
- Meeting modes
- Provider credential storage
- Full UI redesign of provider registration

## Steps

1. Extend `DictationStyle` with optional mode-owned configuration:
   - context policy: include clipboard, include accessibility text, include window OCR, redact sensitive data.
   - post-processing model selection: provider/registration/model matching the existing dictation `EnhancementsAISelection` shape.
   - default marker or a dedicated `defaultDictationStyleID`.
2. Add a non-deletable default mode for existing and new installs. Seed it from current global dictation settings so current installations keep behavior.
3. Preserve priority: first matching user mode for app/site wins; otherwise default mode wins. Do not let the default mode mask a specific app/site mode.
4. Keep migration idempotent. Existing `dictationStyles` must not be duplicated on every launch.
5. Add tests:
   - default mode is created from legacy global context/model settings.
   - app/site mode overrides default.
   - migrated installs preserve selected dictation post-processing model.
   - default mode cannot be deleted or normalized away.
6. Cold review: run thermo-nuclear review focused on whether the default mode created duplicate state or scattered fallback logic. Fix all findings.
7. Committee review gate before plan 021.

## Verification

| Purpose | Command | Expected |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter Dictation` | relevant tests pass |
| Settings compile | `make build-agent` | exit 0 |
| Lane gate | `make build-test` | exit 0 or only documented baseline failures |
| Lint | `make lint` | exit 0, baseline-only output if any |

## Done Criteria

- Default mode exists and adopts legacy global settings.
- Specific modes override default mode.
- No new parallel model-selection store is introduced when existing selection structures can be reused.
