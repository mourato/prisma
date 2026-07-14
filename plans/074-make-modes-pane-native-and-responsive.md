# Plan 074: Make the Modes editor pane native and responsive

> **Executor instructions**: Follow this plan after Plan 073. Run every
> verification command before continuing. Preserve all existing draft and
> persistence behavior. Do not create an `NSPanel` or modal editor.
>
> **Drift check**: `git diff --stat f9f1db2c..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/ModeEditorDrawer.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorDetailView.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/TriggerSelectionView.swift`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: Plan 073
- **Category**: direction
- **Planned at**: commit `f9f1db2c`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: High/Full
- **Parallelizable**: no — pane layout, route state, and draft lifecycle are coupled.
- **Reviewer required**: yes — native navigation semantics and narrow-window behavior need review.
- **Rationale**: This changes the Modes presentation architecture while retaining the existing editor contract.
- **Escalate when**: A native secondary column requires changing the global Settings sidebar or persistence model.

## Why this matters

`ModesSettingsTab` currently builds the list and editor with a plain `HStack`, including a fixed 260–340 point list column. This visually resembles the VoiceInk layout but does not inherit native split-column resizing, collapse, or navigation semantics. The pane also remains allocated when no mode is being edited. This plan makes the secondary editor structurally native and adaptive.

## Current state

- `ModesSettingsTab.swift:15-24` owns the two-column `HStack` and fixed list width.
- `ModesSettingsTab.swift:40-67` renders an empty placeholder when no route is selected.
- `ModeEditorDrawer.swift:57-72` already separates header, scrollable body, and footer.
- `DictationStyleEditorDetailView.swift:88-104` already supplies the drawer with draft callbacks.
- `SettingsPage.swift:60-75` owns the global `NavigationSplitView` and must remain the outer shell.

Use native `NavigationSplitView`/detail semantics where possible. Keep the list visible while editing, but allow the editor column to collapse or disappear when no mode is selected. Do not copy VoiceInk source literally.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Route tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests'` | all selected tests pass |
| Previews | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane full"` | exit 0 or documented baseline failure |

## Scope

**In scope**

- `ModesSettingsTab.swift`
- `ModeEditorDrawer.swift`
- `DictationStyleEditorDetailView.swift` only for layout integration.
- `TriggerSelectionView.swift` and `DictationStylePromptEditorView.swift` only for child-pane sizing.
- Navigation tests and previews.

**Out of scope**

- Motion/transition implementation; Plan 075.
- Confirmation dialogs and button accessibility; Plan 076.
- Typography and validation matrix; Plan 077.
- Persistence, runtime matching, and global sidebar taxonomy.

## Steps

### Step 1: Replace the presentation-only HStack with native column behavior

Use a native split/detail composition compatible with the existing outer settings split. The root Modes state must support list-only and list-plus-editor states. The editor column must have an explicit minimum/ideal width that does not force the overall window beyond supported bounds. Keep route ownership in `ModesSettingsTab`.

**Verify**: route tests pass and `make preview-check` exits 0.

### Step 2: Make the list/editor widths adaptive

Remove the hard minimum that prevents the editor from receiving usable space at narrow widths. Use column width constraints, layout priorities, or a collapsed list state rather than horizontal clipping. Preserve full-width groups inside whichever column receives them.

**Verify**: add normal, narrow, and expanded previews; `make preview-check` passes.

### Step 3: Define the no-selection state

Choose one explicit behavior: collapsed editor column or a lightweight placeholder that does not permanently consume excessive width. Match the product reference and preserve keyboard navigation to the mode list. Do not silently open a mode or create a draft from the empty state.

**Verify**: navigation tests cover root, open editor, close editor, and reopen another mode.

### Step 4: Preserve child routes and footer behavior

Ensure prompt and trigger child routes occupy the same pane, preserve draft state, and do not create additional columns or sheets. Keep the fixed footer owned by `ModeEditorDrawer`.

**Verify**: `make build-agent` and focused route/model tests pass.

## Done criteria

- [ ] Modes uses native split/detail behavior compatible with the outer settings shell.
- [ ] The editor pane can be opened, closed, resized, and collapsed without clipping.
- [ ] The list is not permanently starved by a fixed minimum width.
- [ ] Prompt and trigger child routes remain in the same editor pane.
- [ ] Existing save/cancel/delete draft semantics are unchanged.
- [ ] Focused tests, previews, build, and Full validation pass.
- [ ] `plans/README.md` is updated.

## STOP conditions

- Native split behavior requires changing global Settings taxonomy.
- The only working solution is a custom window/panel.
- Narrow layout requires horizontal scrolling.
- Draft state is lost during column visibility changes.
- Any verification fails twice.

## Maintenance notes

Keep navigation state and pane visibility separate from draft data. Reviewers should verify keyboard focus, VoiceOver column order, and resizing at the minimum supported window size.
