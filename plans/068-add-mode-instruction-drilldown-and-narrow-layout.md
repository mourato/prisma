# Plan 068: Add instruction drill-down and compact mode settings layout

> **Executor instructions**: Execute after Plans 066 and 067. Preserve every existing mode setting unless this plan explicitly reorganizes its presentation. Run each verification gate and stop on the listed conditions.

> **Drift check (run first)**: `git diff --stat f9633e7e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorSheet.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: [066](066-move-dictation-mode-editor-to-detail-panel.md), [067](067-redesign-mode-trigger-search-and-selection.md)
- **Category**: direction
- **Planned at**: commit `f9633e7e`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: Medium/Full
- **Parallelizable**: no — prompt and layout routes share the editor navigation stack.
- **Reviewer required**: yes — ensure no setting becomes unreachable or silently changes behavior.
- **Rationale**: The prompt route changes discoverability and focus behavior inside a stateful editor.
- **Escalate when**: The existing prompt field is consumed by runtime code in a way that requires model changes, or localization removal would break search routes.

## Why this matters

The current prompt `TextEditor` is always visible near the top of a 700px-wide modal (`DictationStyleEditorSheet.swift:125-140`), which makes the editor dense and awkward in a detail panel. The requested interaction is to access instructions through a drill-down, matching the VoiceInk separation of major configuration groups while keeping Prisma’s existing fields: post-processing, Markdown, base-prompt mode, output language, context sources, model selection, default-mode behavior, and target summary.

## Current state

- Prompt text is stored as `DictationStyle.promptInstructions` and copied through `DictationStyleEditorDraft` (`DictationStylesSettingsViewModel.swift:6-45, 91-105`).
- `DictationStyleEditorSheet.swift:125-158` renders prompt, checkboxes, and output language in one vertical form.
- `DictationStyleEditorSheet.swift:160-191` renders context sources, model selection, and default-mode target behavior.
- Existing settings components include `SettingsDrillDownListRow`, `DSGroup`, `CheckboxRow`, `DSMenuPicker`, and `EnhancementsModelPicker`; reuse them.
- Search routing currently maps `settings.styles.*` to `.modes` via `SettingsSearchRouteManifest.swift:44-45`; keep these keys valid.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Localization integrity | `make guidance-check` | exit 0 |
| Preview/layout | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests|SettingsSearchIndexTests'` | all selected tests pass |

## Scope

**In scope**

- The mode editor view produced by Plan 066
- A prompt/instructions child route and compact prompt editor view
- Mode editor section layout and localization strings in `en.lproj` and `pt.lproj`
- Focused prompt/navigation tests

**Out of scope**

- Prompt runtime composition or AI behavior
- Removing any current setting
- Global settings taxonomy or sidebar redesign
- Changing search-route ownership from `.modes`

## Steps

### Step 1: Add an instructions drill-down row

Replace the always-visible `TextEditor` with a `SettingsDrillDownListRow` or equivalent button row. Show a concise summary such as “Not configured” or a truncated instruction preview, without exposing the full prompt in the parent route. Tapping the row pushes the prompt editor while preserving the draft.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests'` → prompt values still round-trip through the draft/model path.

### Step 2: Build the narrow prompt editor destination

Create a compact detail destination with a clear title, multiline `TextEditor`, localized hint, accessible label, and back/save semantics appropriate to a child route. Ensure keyboard focus enters the text editor predictably and that cancel/back does not commit accidental changes unless the parent’s established draft semantics explicitly require it.

**Verify**: `make preview-check` → prompt-editor preview compiles and renders without fixed-width overflow.

### Step 3: Reorganize remaining settings into compact groups

Keep all existing settings reachable through vertically stacked `DSGroup`/`SettingsListGroup` sections. Use single-column rows, flexible labels, and `frame(maxWidth: .infinity, alignment: .leading)` where needed. Keep checkboxes for save-backed booleans and reuse `DSMenuPicker` for output language. The parent editor should show only identity, concise summaries, and drill-down rows; detailed content belongs in child routes.

**Verify**: `make preview-check` → all mode-editor previews compile; no fixed `minWidth` remains in the editor view.

### Step 4: Update localization and search coverage

Add or revise English and Portuguese strings for instruction summary, prompt destination title, trigger destination title, empty state, and narrow-layout hints. Keep old keys that are still referenced; remove only confirmed orphaned keys. Extend `SettingsSearchIndexTests` if newly introduced localization keys are intended search destinations, and keep them routed to `.modes`.

**Verify**: `make guidance-check && swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSearchIndexTests'` → both commands pass.

## Test plan

- Extend `AppSettingsDictationStylesTests` for empty/non-empty instruction summaries and prompt round-trip behavior.
- Add navigation tests for parent → instructions → back and parent → triggers → back, including draft preservation.
- Extend `SettingsSearchIndexTests` only for new user-searchable mode strings.

## Done criteria

- [ ] Full instruction text is accessible only through the instruction drill-down.
- [ ] All current mode settings remain available and persist unchanged.
- [ ] The editor is usable in the narrow settings detail container with no horizontal clipping.
- [ ] No new non-localized user-facing strings are introduced.
- [ ] Focused tests, `make preview-check`, `make build-agent`, and `make guidance-check` pass.

## STOP conditions

- Any setting would need to be removed, renamed in persistence, or moved to runtime code.
- Back/cancel semantics cannot preserve the existing unsaved-draft contract.
- The settings search index cannot safely distinguish parent and child mode routes.
- The editor still requires a fixed width or a new global settings-shell change.

## Maintenance notes

Treat the parent mode editor as a summary surface and child routes as detail surfaces. Future mode settings should first define their summary, destination route, draft ownership, and localization/search behavior before adding another always-visible control.
