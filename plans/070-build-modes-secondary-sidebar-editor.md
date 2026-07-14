# Plan 070: Build the Modes secondary-sidebar editor

> **Executor instructions**: Follow this plan step by step. Run every verification command before moving to the next step. If a STOP condition is reached, stop and report it; do not improvise. Implement the drawer as native SwiftUI navigation/layout. Do not build a custom floating `NSPanel`.
>
> **Drift check (run first)**: `git diff --stat 2fc835f8..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorDetailView.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStylePromptEditorView.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/TriggerSelectionView.swift`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: Plan 069
- **Category**: direction
- **Planned at**: commit `2fc835f8`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: High/Full
- **Parallelizable**: no — drawer, route state, draft lifecycle, and settings shell are coupled.
- **Reviewer required**: yes — review focus, route transitions, unsaved drafts, and fixed actions.
- **Rationale**: This changes the Modes presentation architecture while preserving mode persistence.
- **Escalate when**: A true third column requires changing global sidebar taxonomy, persistence, or an AppKit window controller.

## Why this matters

The current editor replaces the entire settings detail content. The target interaction keeps the Modes list visible and opens a right-side secondary detail pane, matching the supplied VoiceInk reference. The pane needs a mode icon/title header, an X close action, independently scrolling content, and fixed Delete/Save actions at the bottom. Existing draft fields, child routes, validation, and persistence must remain intact.

## Current state

- `ModesSettingsTab.swift:15-29` switches the whole detail surface between list, editor, trigger selection, and prompt editor.
- `ModesSettingsTab.swift:31-77` constructs `DictationStyleEditorDetailView` and owns save/cancel/delete callbacks.
- `DictationStyleEditorDetailView.swift:88-203` renders a header plus a single `ScrollView` containing identity, instructions, behavior, context, model, and targets.
- `DictationStyleEditorDetailView.swift:210-249` currently places Cancel, Delete, and Save in a top header.
- `DictationStylePromptEditorView.swift:17-65` and `TriggerSelectionView.swift:36-87` have their own top headers and must remain usable as child destinations.
- `SettingsPage.swift:60-73` already owns the global `NavigationSplitView`; do not replace it.

The screenshot is the visual target: list pane visible, editor pane on the right, header with icon/title/X, and footer with fixed Delete/Save. The local VoiceInk checkout uses native split/detail navigation but may not contain the exact screenshot version; copy interaction principles, not source code.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Navigation/model tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests'` | all selected tests pass |
| Previews | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Full validation | `make validate-agent ARGS="--lane full"` | exit 0, or documented baseline failure only |

## Suggested executor toolkit

- Use `macos-app-engineering` for native `NavigationSplitView` and settings-shell behavior.
- Use `swiftui-pro` for state ownership, focus, adaptive layout, and scroll behavior.
- Use `apple-design` for drawer transition, close affordance, materials, and Reduce Motion behavior.

## Scope

**In scope**

- `ModesSettingsTab.swift`
- `DictationStyleEditorDetailView.swift`
- `DictationStylePromptEditorView.swift`
- `TriggerSelectionView.swift` only for shared drawer-header/footer integration.
- `DictationStyleRoute.swift` only if route state needs an explicit editor selection state.
- Focused navigation/view-model tests and previews.

**Out of scope**

- Changing `DictationStyle`, JSON persistence, or runtime matching.
- Rewriting the global Settings sidebar.
- New trigger types such as keyboard shortcuts.
- Reworking every settings group; Plan 071 owns group-width normalization.

## Steps

### Step 1: Choose the native secondary-pane structure

Use the existing global `NavigationSplitView` as the outer shell. Add the narrowest native structure that keeps the Modes list visible while presenting the editor on the right. Prefer a nested detail split or equivalent native detail-column composition over an overlay window. Required states are root list, editor, trigger child, and prompt child. Do not use `.sheet`, `.popover`, or a custom `NSPanel` for the editor.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests'` → all selected tests pass.

### Step 2: Build the drawer header

Create a reusable header for the editor and child destinations. It must contain the current mode icon using `DictationStyleIconView`, the mode name, an accessible X close button, and a visual boundary from scrollable content. Closing follows current cancel semantics and never autosaves. Child routes use back, not close-the-editor semantics.

**Verify**: `make preview-check` → normal and narrow header previews compile; no new editor presentation uses `.sheet`, `.popover`, or `NSPanel`.

### Step 3: Move actions into a fixed footer

Separate the editor body from its bottom action bar. The body remains scrollable. The footer is always visible and contains Delete on the leading side for existing non-default modes and Save/Create on the trailing side. Use `safeAreaInset(edge: .bottom)` or an equivalent dedicated container, with bottom scroll padding so the final group is not hidden.

**Verify**: `make preview-check` → narrow preview keeps footer visible; focused model tests pass.

### Step 4: Preserve child routes and draft ownership

Adapt prompt and trigger destinations to the drawer shell without duplicating save/delete logic. Parent editor state remains the source of truth. Back preserves unsaved changes; editor close/cancel clears the draft according to the view-model contract.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests'` → all selected tests pass.

### Step 5: Add interaction and width previews

Add previews for root list, populated editor, prompt child, trigger child, and a narrow drawer width. The narrow preview must show wrapping/compression without horizontal clipping and keep footer actions visible.

**Verify**: `make preview-check && make build-agent` → both commands exit 0.

## Test plan

- Extend route tests for root → editor → child → editor → close.
- Test close/cancel does not persist unsaved changes to name, prompt, context, model, or targets.
- Test create, save, delete, default-mode protection, and reopening another mode.
- Verify the footer is outside scroll content if a view-inspection test facility exists.

## Done criteria

- [ ] Modes list remains visible beside the right-side editor pane.
- [ ] Header displays icon, title, and accessible X close button.
- [ ] Editor body scrolls independently from the fixed footer.
- [ ] Delete and Save/Create remain visible while scrolling.
- [ ] Prompt and trigger child routes preserve the draft.
- [ ] No editor `.sheet`, `.popover`, or custom `NSPanel` exists.
- [ ] Focused tests, previews, build, and Full validation pass.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

- The third-column implementation requires changing global sidebar taxonomy or persistence.
- SwiftUI cannot keep the footer visible without a custom AppKit panel.
- Close would discard data differently from current cancel behavior.
- A child route requires a second independent draft or autosave.
- The editor only works by hiding the Modes list.

## Maintenance notes

Keep the drawer container responsible for header, scroll region, safe-area insets, and footer. Child screens supply content and local back actions only. Review focus, VoiceOver labels, narrow widths, and Reduce Motion.
