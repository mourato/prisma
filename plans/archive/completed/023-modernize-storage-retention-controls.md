# Plan 023: Modernize storage retention controls

> **Executor instructions**: Execute on `main` after plan 022 review completes. Run the drift check first. After implementation, run the cold review step and fix every finding before marking DONE.
>
> **Drift check**: `git diff --stat d3ad6d8d..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/GeneralSettingsViewModel.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: 022
- **Category**: direction
- **Planned at**: commit `d3ad6d8d`, 2026-07-03

## Why this matters

Storage retention currently uses a toggle plus arbitrary text input. The requested UI is a picker with common retention periods, an option to disable the limit, and an immediate cleanup button using the selected policy.

## Current state

- `GeneralSettingsTab.swift:130` renders `autoDeleteTranscriptions` as a toggle.
- `GeneralSettingsTab.swift:145` renders `autoDeletePeriodDays` as a free text field.
- `GeneralSettingsTab.swift:164` already has a cleanup-now button.
- `GeneralSettingsViewModel` persists `autoDeleteTranscriptions` and `autoDeletePeriodDays`.

## Scope

**In scope**
- Retention option enum or view-model helper
- Picker UI for disabled, 1 week, 2 weeks, 1 month, 3 months, 6 months
- Cleanup-now button behavior and copy
- Tests for mapping between picker and existing settings keys

**Out of scope**
- Core Data retention schema changes
- History metadata deletion policy
- Changing the cleanup service contract unless required

## Steps

1. Add a small retention option type with values:
   - disabled
   - 7 days
   - 14 days
   - 30 days
   - 90 days
   - 180 days
2. Map the option to existing `autoDeleteTranscriptions` and `autoDeletePeriodDays`; do not introduce a new persistence key unless necessary.
3. Replace the toggle/text field with one menu picker.
4. Keep the cleanup-now button visible when a retention limit is selected. Disable it while cleanup is running.
5. Update confirmation copy so it uses the selected option label.
6. Add tests for legacy settings mapping:
   - disabled when `autoDeleteTranscriptions == false`.
   - existing arbitrary day count normalizes to the closest supported option or preserves a hidden custom value only if product requires it. Prefer closest supported option.
7. Cold review: verify the UI is simpler, localized, and does not add redundant storage state. Fix all findings.

## Verification

| Purpose | Command | Expected |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter GeneralSettings` | relevant tests pass |
| UI previews | `make preview-check` | exit 0 |
| Fast gate | `make scope-check` | exit 0 |

## Done Criteria

- Storage retention uses a picker, not a toggle plus text field.
- Cleanup-now still works for the selected limit.
- Existing settings migrate without losing the user's retention intent.
