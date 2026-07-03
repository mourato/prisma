# Plan 021: Move context and model controls into modes

> **Executor instructions**: Execute on `main` after plan 020 review completes. Run the drift check first. After implementation, run the cold review step and fix every finding before marking DONE.
>
> **Drift check**: `git diff --stat d3ad6d8d..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/DictationSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/EnhancementsSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/Services/PostProcessingConfigurationProvider.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerContextCapture.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 020
- **Category**: direction
- **Planned at**: commit `d3ad6d8d`, 2026-07-03

## Why this matters

After modes own context source and post-processing model configuration, the global controls in Intelligence/Dictation become duplicate state. Runtime behavior must read the effective mode, not stale global settings, while preserving protected-app safety globally.

## Current state

- `EnhancementsSettingsTab` renders context source toggles and protected apps.
- `DictationSettingsTab` renders the dictation model selector as a global group.
- `ContextAwarenessService` already accepts per-call `ContextAwarenessCaptureOptions`, so mode-specific options can be resolved before capture without changing OCR/AX internals.
- `PostProcessingConfigurationProvider` already resolves dictation style matches for prompt behavior.

## Scope

**In scope**
- Mode editor UI in `StylesSettingsTab`
- Effective mode resolver used by prompt/model/context capture
- Removal of global context-source controls from Intelligence
- Removal of global dictation post-processing model selector from Dictation root
- Localization and settings search updates

**Out of scope**
- Removing protected apps; they move in plan 022.
- New provider credential UX.
- Meeting post-processing model behavior.

## Steps

1. Add context-source controls to the mode editor:
   - clipboard
   - accessibility text
   - window OCR
   - sensitive-data redaction
   Use localized strings only.
2. Add post-processing model selection to the mode editor. Reuse `EnhancementsModelSelectionControl` or its view-model logic; do not create a second provider/model picker from scratch.
3. Add an effective-mode resolver for dictation capture that returns the specific matching mode or default mode.
4. Feed effective-mode context options into context capture. Preserve protected apps and hard redaction safety.
5. Feed effective-mode model selection into dictation post-processing readiness and request construction.
6. Remove the global dictation model group from `DictationSettingsTab`.
7. Remove context-source toggles from `EnhancementsSettingsTab`; leave protected apps until plan 022 moves them.
8. Update `SettingsSearchIndex` and `Localizable.strings` so deleted controls are no longer searchable in their old locations.
9. Add tests for runtime effective model and context options.
10. Cold review: verify no stale global controls remain and no fallback logic is duplicated across UI/runtime. Fix all findings.
11. Committee review gate before plan 022.

## Verification

| Purpose | Command | Expected |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter PostProcessingConfigurationProvider` | relevant tests pass |
| UI previews | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Lane gate | `make build-test` | exit 0 or only documented baseline failures |
| Lint | `make lint` | exit 0, baseline-only output if any |

## Done Criteria

- Context-source and dictation model controls live in modes.
- Runtime dictation uses the effective mode.
- Old global instances are removed from Intelligence/Dictation.
