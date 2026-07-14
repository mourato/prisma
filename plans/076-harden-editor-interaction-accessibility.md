# Plan 076: Harden editor interaction safety and accessibility

> **Executor instructions**: Follow this plan after Plan 075. Run every
> verification command before continuing. Do not change persisted mode behavior
> except to add confirmation before an existing destructive action.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: Plan 074
- **Category**: bug
- **Planned at**: commit `f9f1db2c`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: Medium/Full
- **Parallelizable**: no — actions, focus, and route dismissal share the drawer.
- **Reviewer required**: yes — destructive behavior and VoiceOver labels need review.
- **Rationale**: The changes are contained but affect irreversible actions and keyboard users.
- **Escalate when**: The app has an existing deletion policy that intentionally forbids confirmation dialogs.

## Why this matters

The drawer now exposes a fixed destructive Delete action and icon-only controls. Delete currently executes immediately, and labels are supplied through `accessibilityLabel` rather than the preferred textual button-label pattern. This plan improves agency, confirmation, VoiceOver, keyboard navigation, and focus without changing mode data contracts.

## Current state

- `ModeEditorDrawer.swift:132-142` creates an X button with only an image label.
- `ModeEditorDrawer.swift:144-156` creates a back button with a visible text label.
- `ModeEditorDrawer.swift:158-178` exposes Delete and Save in the fixed footer.
- `ModesSettingsTab.swift:95-101` directly calls `deleteStyle` from the footer action.
- `DictationStyleEditorDetailView.swift:135-147` creates an icon-only SF Symbol menu trigger.
- `TriggerSelectionView.swift:156-164` has a destructive remove button with an accessible label.

Use `Button("Close", systemImage: "xmark")`/`Button("Choose icon", systemImage: ...)` with `.labelStyle(.iconOnly)` when the visual design is icon-only. Attach `confirmationDialog` to the UI that triggers deletion, as required by SwiftUI navigation/accessibility guidance.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests|SettingsSubpageNavigationStateTests'` | all selected tests pass |
| Previews | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |

## Scope

**In scope**

- `ModeEditorDrawer.swift`
- `ModesSettingsTab.swift`
- `DictationStyleEditorDetailView.swift`
- `TriggerSelectionView.swift` only for labels/focus of touched controls.
- Localization strings for new confirmation/accessibility copy.
- Focused tests/previews.

**Out of scope**

- Navigation architecture; Plan 074.
- Motion; Plan 075.
- Typography and preview matrix; Plan 077.
- Undo system, persistence schema, or runtime matching.

## Steps

### Step 1: Add deletion confirmation

Introduce a local confirmation state at the drawer/editor owner. Delete should first present a localized confirmation dialog identifying the mode when appropriate. Only the confirmation action calls the existing `deleteStyle` callback. Keep default-mode deletion unavailable.

**Verify**: extend view-model/route tests for delete callback intent where test infrastructure permits; existing model tests pass.

### Step 2: Normalize icon-only button labels

Convert close and icon-picker controls to text-backed button labels while preserving visual icon-only appearance. Add explicit accessibility hints only when they communicate an action beyond the label. Keep Escape keyboard behavior for close/back.

**Verify**: `make preview-check` → controls compile and remain visually compact; `rg -n 'Button \{|Image\(systemName: "xmark"|square.grid.2x2'` confirms touched controls use text-backed labels.

### Step 3: Verify keyboard and VoiceOver flow

Check focus order: mode list → editor header → editor content → footer. Ensure close/back returns focus to the initiating row. Ensure selected/conflicting app rows expose their state and disabled controls are not announced as actionable.

**Verify**: add or update accessibility-focused tests only if an existing inspection facility exists; otherwise document manual checks and run `make preview-check`.

### Step 4: Preserve draft semantics

Confirm closing, canceling, and dismissing the delete dialog do not save or discard the draft unexpectedly. Only confirmed Delete, Save/Create, and parent Cancel perform their existing mutations.

**Verify**: focused model and navigation tests pass.

## Done criteria

- [ ] Delete requires explicit confirmation and remains unavailable for the default mode.
- [ ] Close and icon-picker controls have text-backed accessibility labels.
- [ ] Keyboard Escape and VoiceOver routes remain predictable.
- [ ] App selection states are announced correctly.
- [ ] Draft/persistence semantics are unchanged.
- [ ] Focused tests, previews, and build pass.
- [ ] `plans/README.md` is updated.

## STOP conditions

- Confirmation conflicts with an existing documented product policy.
- Focus restoration cannot be implemented without changing global navigation.
- A control needs a custom AppKit accessibility bridge.
- Any verification fails twice.

## Maintenance notes

Every destructive action added to the drawer must use the same confirmation and accessibility pattern. Keep visible labels, accessibility labels, keyboard shortcuts, and localization keys synchronized.
