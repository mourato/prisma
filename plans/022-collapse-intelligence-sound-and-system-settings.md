# Plan 022: Collapse Intelligence, Sound, and System into Settings

> **Executor instructions**: Execute on `main` after plan 021 review completes. Run the drift check first. After implementation, run the cold review step and fix every finding before marking DONE.
>
> **Drift check**: `git diff --stat d3ad6d8d..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 021
- **Category**: direction
- **Planned at**: commit `d3ad6d8d`, 2026-07-03

## Why this matters

The current UI still exposes an Intelligence page with a segmented control and separate Sound/System concepts. The requested end state removes Intelligence, moves its contents to domain-appropriate places, moves Sound under the renamed Settings tab, and pins Settings at the bottom of the sidebar.

## Current state

- `IntelligenceSettingsTab.swift:47` renders the segmented control for Models/Text and Context/Dictionary.
- `SettingsSection.swift:50` lists `.intelligence`, `.system`, and `.audio` under settings sections.
- `SettingsSection.swift:88` redirects legacy `.models`, `.enhancements`, and `.vocabulary` to `.intelligence`.
- `SystemSettingsTab` currently routes only root and permissions.
- `GeneralSettingsTab.swift:126` owns storage controls.
- `AudioSettingsTab` owns audio/sound content as a top-level sidebar destination.

## Scope

**In scope**
- `SettingsSection`, `SettingsDestination`, sidebar grouping
- `SystemSettingsTab` renamed/retitled as Settings
- Drill-down routes for Models, Dictionary, Sound, Permissions
- Protected Apps moved to Settings/System
- Post-processing group moved to Dictation
- Search/localization/navigation tests

**Out of scope**
- Source directory renames unless required by compiler
- Runtime model/provider behavior beyond navigation
- Mode-owned context/model runtime already handled by plan 021

## Steps

1. Rename visible System tab to "Settings" via localization and title routing. Keep internal enum name only if that avoids unnecessary churn.
2. Remove `.intelligence` and `.audio` from visible sidebar sections.
3. Add bottom placement for the renamed Settings row in `SettingsSidebarView`. Prefer a native sidebar/list structure; a `Spacer` is acceptable if it remains stable with search.
4. Add `SystemSettingsRoute` cases for `.models`, `.dictionary`, `.sound`, and `.permissions`, in that order on the Settings root.
5. Move Models and Dictionary bodies into Settings drill-down routes.
6. Move Sound content into the Settings/Sound drill-down.
7. Move Protected Apps into Settings root or a Settings drill-down, matching the requested System destination.
8. Move the remaining Post-processing group from Text and Context to Dictation.
9. Delete `IntelligenceSettingsTab` from active routing once no visible route depends on it; keep legacy redirects from `.models`, `.enhancements`, and `.vocabulary` to their new destinations.
10. Update `SettingsSearchIndex` so old Intelligence keys route to the new destinations.
11. Update tests for legacy raw values, search routing, visible sidebar order, and Settings bottom placement.
12. Cold review: run the semaforo review with thermo pass focused on routing sprawl, legacy redirects, and duplicated page bodies. Fix all findings.
13. Committee review gate before plan 023.

## Verification

| Purpose | Command | Expected |
|---|---|---|
| Navigation tests | `swift test --package-path Packages/MeetingAssistantCore --filter Settings` | relevant tests pass |
| UI previews | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Lane gate | `make build-test` | exit 0 or only documented baseline failures |
| Lint | `make lint` | exit 0, baseline-only output if any |

## Done Criteria

- No visible Intelligence tab remains.
- Models, Dictionary, Sound, and Permissions are Settings drill-downs in that order.
- Settings is visually pinned at the bottom of the sidebar.
- Search and legacy deep links resolve correctly.
