# Plan 075: Add interruptible Modes pane transitions

> **Executor instructions**: Follow this plan after Plan 074. Run every
> verification command before continuing. Motion must be subtle, reversible,
> and disabled/replaced appropriately for Reduce Motion.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: Plan 074
- **Category**: direction
- **Planned at**: commit `f9f1db2c`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: Medium/Full
- **Parallelizable**: no — transition state depends on the native pane state.
- **Reviewer required**: yes — motion, reversal, and accessibility behavior need visual review.
- **Rationale**: The feature is visually contained but can make navigation feel broken if transitions are not symmetric.
- **Escalate when**: A gesture-driven interactive drag or AppKit animator becomes necessary.

## Why this matters

The current route changes show the editor without a directional transition. The VoiceInk reference communicates a right-side drawer, so entry and exit should preserve spatial orientation. Apple-style motion requires symmetric, interruptible transitions and a Reduce Motion alternative.

## Current state

- `ModesSettingsTab.swift:38-52` switches route content without an explicit transition.
- `ModeEditorDrawer.swift:57-72` owns the pane content but does not own presentation animation.
- No current Modes-specific motion or `accessibilityReduceMotion` environment value exists in the touched files.

Use a shared design-system animation if one exists. Prefer a short critically damped spring or native column animation; do not invent a local animation vocabulary. If the pane is implemented as a native split column in Plan 074, animate column visibility/width rather than applying a large independent offset to the entire settings window.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Previews | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests'` | all selected tests pass |

## Scope

**In scope**

- `ModesSettingsTab.swift`
- `ModeEditorDrawer.swift` only if the transition contract belongs there.
- Existing animation/design-system constants if needed.
- Motion previews or focused tests.

**Out of scope**

- Changing the pane architecture; Plan 074.
- New gestures, drag-to-dismiss, or custom AppKit animation.
- Persistence and settings content layout.

## Steps

### Step 1: Define the transition contract

Opening moves/appears from the right-side editor origin. Closing returns toward the same origin. Child route changes use a smaller back-navigation transition and must not animate the entire global sidebar. Keep the list visually stable.

**Verify**: add a deterministic preview for open/closed states; `make preview-check` passes.

### Step 2: Implement native, reversible motion

Use `withAnimation`/`.animation(_:value:)` tied to pane visibility or route state. Do not use unbounded animation, delayed chained animations, or a one-way transition. If the native split API already animates the column, do not add a second competing transition.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests'` and `make build-agent` pass.

### Step 3: Add Reduce Motion behavior

Read `@Environment(\.accessibilityReduceMotion)`. Replace slide/spring motion with a short opacity or static state change when enabled. Ensure the pane still has clear visual state and focus moves deterministically.

**Verify**: preview includes Reduce Motion and normal-motion variants; `make preview-check` passes.

### Step 4: Verify focus and interruption

Confirm opening focuses the editor meaningfully, closing returns focus to the selected mode row, and rapidly opening/closing does not leave stale child content visible. Do not block input during the transition.

**Verify**: route tests pass; document manual preview checks in the handoff.

## Done criteria

- [ ] Opening and closing preserve right-side spatial orientation.
- [ ] Child navigation does not animate the global settings shell.
- [ ] Motion is reversible and tied to state changes.
- [ ] Reduce Motion uses a non-sliding alternative.
- [ ] Focus behavior is documented and verified.
- [ ] Previews, focused tests, and build pass.
- [ ] `plans/README.md` is updated.

## STOP conditions

- The transition jumps, blocks input, or requires a fixed timer.
- A native split transition and custom transition conflict.
- Reduce Motion cannot be honored without removing navigation feedback.
- A gesture or AppKit animator is required beyond this scope.

## Maintenance notes

Keep motion constants centralized. Future drawers should reuse the same transition and Reduce Motion contract instead of adding per-screen animation values.
