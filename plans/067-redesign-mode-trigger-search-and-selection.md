# Plan 067: Redesign mode trigger search, selection, and removal

> **Executor instructions**: Read Plan 066 first and execute this plan only after its detail-panel route exists. Run every verification command before continuing. Stop rather than improvising when a STOP condition occurs.

> **Drift check (run first)**: `git diff --stat f9633e7e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/settings/AppSearchInlineSection.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/AppSearchSheet.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorSheet.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: [066](066-move-dictation-mode-editor-to-detail-panel.md)
- **Category**: direction
- **Planned at**: commit `f9633e7e`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: High/Full
- **Parallelizable**: no — trigger routes edit the same draft owned by Plan 066.
- **Reviewer required**: yes — app/site normalization and exclusivity are behavior-sensitive.
- **Rationale**: This is a UI redesign with validation and identity rules, not a cosmetic component swap.
- **Escalate when**: A trigger needs a new persisted type, browser-specific matching, or a change to `DictationStyleTarget.matches`.

## Why this matters

The current editor puts app search, website input, selected targets, and conflict validation in one wide form (`DictationStyleEditorSheet.swift:222-375`). VoiceInk separates “When to Trigger” from the rest of the editor and uses a searchable app picker with toggle selection (`../VoiceInk/VoiceInk/PowerMode/PowerModeConfigView.swift:245-387`, `../VoiceInk/VoiceInk/PowerMode/AppPicker.swift:10-68`). Prisma should adopt that interaction while retaining its stronger existing invariant: one app/site target belongs to only one non-default mode.

## Current state

- `DictationStyleTarget` supports `.app(bundleIdentifier:)` and `.website(url:)` and normalizes identity in `DictationStyle.swift:82-165`.
- `DictationStylesSettingsViewModel.styleNameConflicting` enforces cross-mode exclusivity in `DictationStylesSettingsViewModel.swift:169-182`.
- `AppSearchInlineSection.swift:40-117` filters by display name or bundle identifier and exposes one Add button per result.
- `DictationStyleEditorSheet.swift:222-250` currently combines app search and website input; `:330-375` renders selected targets as rows with destructive removal.
- VoiceInk’s picker displays a searchable, sorted app grid and toggles selection, while its website UI uses normalized URL chips. In Prisma’s narrower detail panel, use compact list rows/chips rather than a fixed 600x500 grid.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Model tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests'` | all selected tests pass |
| Preview/layout | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Localization | `make guidance-check` | exit 0 |

## Scope

**In scope**

- Trigger-selection views/components under `Sources/UI/components/settings/`
- `DictationStyleEditorSheet.swift` or its Plan 066 successor
- `AppSearchInlineSection.swift` only if it becomes an explicitly reusable picker
- `DictationStylesSettingsViewModel.swift` for draft-level trigger actions
- English and Portuguese localization strings for the new trigger UI
- `AppSettingsDictationStylesTests.swift` and focused component/state tests where practical

**Out of scope**

- Changing `DictationStyleTarget` storage shape
- Changing active-app or active-URL matching semantics
- Allowing a target to belong to multiple modes
- Global app discovery performance redesign

## Steps

### Step 1: Add a trigger-selection child route

Create a child route from the mode editor labeled “Apps and Websites” or the localized equivalent. The summary row must show selected-target count and a chevron. The child view owns search text and temporary selection interaction but writes additions/removals into the parent draft through explicit callbacks or bindings.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|AppSettingsDictationStylesTests'` → all selected tests pass.

### Step 2: Implement searchable app selection

Reuse `InstalledApplicationRecord`, `AppCatalogDiscovery`, and `AppIconView`. Match VoiceInk’s behavior: case-insensitive search by app name and bundle ID, deterministic alphabetical ordering, and a clear-search affordance. Display selected apps as compact rows with icon, name, bundle ID, selected state, and remove action. Do not use a fixed-width grid; the detail panel may be as narrow as the existing settings detail column.

**Verify**: `make preview-check` → exit 0; preview or state tests cover empty, loading, search match, search miss, already-selected, and remove cases.

### Step 3: Implement website selection and normalization

Provide a compact website search/add flow and selected website rows/chips. Preserve the current accepted input behavior and duplicate prevention, but centralize normalization so `https://`, `http://`, whitespace, casing, and blank values are handled consistently with `DictationStyleTarget` identity/matching. Do not introduce browser bundle identifiers or domain-specific matching in this plan.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests'` → duplicate, blank, case-normalized, and persisted website cases pass.

### Step 4: Preserve conflict validation at add and save

Keep immediate conflict feedback when adding a target and repeat validation on save. The UI must identify the owning mode when available, must not mutate the other mode, and must not allow a duplicate target within the current draft.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests'` → exclusivity and duplicate-target tests pass.

## Test plan

- Extend `AppSettingsDictationStylesTests` for app/site normalization and cross-mode conflict behavior.
- Add pure filtering/normalization tests if the picker logic is extracted; keep SwiftUI rendering thin.
- Use `AppSearchInlineSection` filtering rules as the baseline, but make sorting and selection behavior explicit and deterministic.

## Done criteria

- [ ] Trigger editing is a child drill-down, not a wide inline form.
- [ ] Apps support search by name/bundle ID, sorted results, selected state, and removal.
- [ ] Websites support add/search-oriented interaction, duplicate prevention, and removal.
- [ ] Existing exclusivity and runtime matching contracts remain unchanged.
- [ ] The UI remains usable at the narrow settings detail width.
- [ ] English/Portuguese strings are localized and `make guidance-check` passes.

## STOP conditions

- The target model cannot represent the desired UI without a persistence migration.
- The implementation proposes changing runtime URL matching or app detection.
- Conflict ownership becomes ambiguous for existing persisted data.
- A fixed-width grid or modal is required to make the interaction usable.

## Maintenance notes

Keep target identity in one place. Any future trigger type must define normalization, display, duplicate identity, conflict behavior, and runtime matching together, with tests before UI wiring.
