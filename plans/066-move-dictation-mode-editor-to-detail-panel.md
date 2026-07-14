# Plan 066: Move dictation-mode editing from a sheet to a settings detail panel

> **Executor instructions**: Follow this plan step by step. Run every
> verification command before moving to the next step. If a STOP condition is
> reached, stop and report; do not improvise.

> **Drift check (run first)**: `git diff --stat f9633e7e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorSheet.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift Packages/MeetingAssistantCore/Sources/UI/Models/SettingsSubpageNavigationState.swift`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `f9633e7e`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: High/Full
- **Parallelizable**: no — this changes the owner of editor navigation state.
- **Reviewer required**: yes — detail navigation, draft lifetime, and cancel/save behavior are coupled.
- **Rationale**: The change crosses SwiftUI navigation, view-model state, and the existing editor surface.
- **Escalate when**: The settings shell cannot host a nested detail route without changing `SettingsPage.swift`, or the current save contract requires a persistence migration.

## Why this matters

Prisma currently opens the entire mode editor as a modal sheet, while the target interaction is an in-settings detail panel. VoiceInk’s relevant pattern is a list/detail flow: its `ContentView` uses `NavigationSplitView` (`../VoiceInk/VoiceInk/Views/ContentView.swift:75-141`) and its Power Mode list pushes `ConfigurationView` with `navigationDestination` (`../VoiceInk/VoiceInk/PowerMode/PowerModeView.swift:69-257`). Moving the mode editor into the existing settings detail surface makes the editor feel native in the narrower container and enables further drill-down routes without stacking sheets.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift:5-48` owns the mode list and presents `DictationStyleEditorSheet` with `.sheet(isPresented:)`.
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift:49-142` owns `showEditor`, an optional `editorDraft`, and save/cancel behavior.
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorSheet.swift:79-215` is a 700x720 scrollable form containing every setting, prompt text editor, and targets editor.
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsDrillDownListRow.swift:3-29` is the existing native drill-down row pattern and should be reused.
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift:59-85` already supplies the app-level `NavigationSplitView`; do not redesign the global sidebar.
- `DictationStyle`, `DictationStyleEditorDraft`, and `AppSettingsStore.dictationStyles` already provide the persisted data contract. Do not rename fields or migrate JSON in this plan.

VoiceInk’s editor itself is a full detail destination, not a literal floating panel: `PowerModeView.swift:254-255` routes to `ConfigurationView`; `PowerModeConfigView.swift:122-165` provides a title/actions header and scrollable content. Adapt that interaction to Prisma’s native settings components; do not copy VoiceInk’s custom card styling wholesale.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Guidance | `make guidance-check` | exit 0 |
| Preview/layout | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSearchIndexTests|AppSettingsDictationStylesTests'` | all selected tests pass |

## Scope

**In scope**

- `StylesSettingsTab.swift`
- `DictationStylesSettingsViewModel.swift`
- `DictationStyleEditorSheet.swift` (rename or split into an editor detail view if that is the cleanest owner)
- A new mode-editor navigation state/model under `Sources/UI/Models/` if needed
- Focused navigation tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`

**Out of scope**

- `DictationStyle` persistence fields or JSON compatibility
- Runtime trigger matching
- Global `SettingsPage` sidebar taxonomy
- VoiceInk source files

## Steps

### Step 1: Introduce explicit mode-editor route state

Replace the boolean-plus-optional-draft presentation contract with an explicit route that can represent the mode list and an editing destination, while preserving the existing draft construction and `saveStyle` normalization. Keep cancel as a route pop/clear operation and ensure opening a different mode replaces stale draft state. Model the route after `SettingsDrillDownListRow` and existing settings navigation state types, not after a modal presentation flag.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|AppSettingsDictationStylesTests'` → all selected tests pass.

### Step 2: Render the editor in the settings detail column

Remove the mode-editor `.sheet` presentation from `StylesSettingsTab`. Add a root/list view and a detail destination inside the same settings content hierarchy. The detail header must expose back/cancel, save/create, and destructive delete for existing non-default modes. Preserve `onDeleteCommand`, context-menu edit/delete, and selection behavior. The editor must use flexible width and vertical scrolling; remove the fixed `minWidth: 700` requirement.

**Verify**: `make preview-check` → exit 0 with no preview compilation errors.

### Step 3: Preserve draft and lifecycle behavior

Verify create, edit, cancel, save, delete, default-mode protection, and reopening after save. Add or update tests for route transitions and draft clearing. Do not autosave edits: changes remain local until Save, matching the existing `onSave` contract.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests|SettingsSubpageNavigationStateTests'` → all selected tests pass.

## Test plan

- Add route tests for opening create, opening edit, canceling, saving, and replacing an existing route with another mode.
- Preserve and run `AppSettingsDictationStylesTests` for target exclusivity, default fallback, and persistence semantics.
- Use `SettingsSubpageNavigationStateTests.swift` as the navigation-state test pattern.

## Done criteria

- [ ] No `.sheet` presents `DictationStyleEditorSheet` from `StylesSettingsTab`.
- [ ] Editing a mode renders in the settings detail column and supports back/cancel/save/delete.
- [ ] The editor has no fixed width that overflows a narrow detail container.
- [ ] Existing persisted fields and runtime matching behavior are unchanged.
- [ ] Focused tests, `make preview-check`, and `make build-agent` pass.
- [ ] Only in-scope files are modified.

## STOP conditions

- The live code no longer matches the current-state excerpts and the route contract cannot be inferred safely.
- Implementing the detail flow requires changing `SettingsPage.swift` or global sidebar taxonomy.
- A persistence migration or runtime matching change appears necessary.
- A focused test fails twice after a reasonable correction.

## Maintenance notes

Keep editor navigation state local to the modes feature. Future nested destinations (instructions, trigger selection) must be added as child routes, not new sheets. Review draft ownership carefully: a route change must not silently save or discard edits.
