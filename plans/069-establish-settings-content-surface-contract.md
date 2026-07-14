# Plan 069: Establish a shared settings content-surface contract

> **Executor instructions**: Follow this plan step by step. Run every verification command before moving to the next step. If a STOP condition is reached, stop and report it; do not improvise. This plan establishes shared layout behavior only. Do not implement the Modes drawer in this plan.
>
> **Drift check (run first)**: `git diff --stat 2fc835f8..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsScrollableContent.swift Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSGroup.swift`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `2fc835f8`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: Medium/Full
- **Parallelizable**: no — this changes the shared settings shell used by all tabs.
- **Reviewer required**: yes — incorrect insets can affect every settings destination.
- **Rationale**: The change is localized to SwiftUI settings chrome but has cross-tab visual impact.
- **Escalate when**: A correct safe-area contract requires changing window/AppKit configuration or changing sidebar taxonomy.

## Why this matters

Some settings tabs reserve space below the navigation toolbar while Modes starts directly below it. `SettingsDetailChromeModifier` returns content unchanged when toolbar chrome is active. Modes also has an embedded path that bypasses `SettingsScrollableContent`, so its outer group can touch the page edges. This plan creates one reusable page-surface contract for top spacing, horizontal gutters, scrolling, and background ownership.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift:60-73` owns the app-level `NavigationSplitView` and applies `SettingsDetailChromeModifier`.
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift:519-531` inserts a top safe-area header only when `usesToolbarChrome` is false; toolbar mode returns the content directly.
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsScrollableContent.swift:16-32` owns a `GeometryReader`, scrolling, and a 20-point horizontal gutter.
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift:24-32` bypasses `SettingsScrollableContent` when `embedded` is true.
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSGroup.swift:52-78` owns group headers and settings cards, but not page-level gutters.

Preserve the existing `NavigationSplitView` and `List(.sidebar)` semantics. Reuse `SettingsWindowBackground`, `SettingsScrollableContent`, `DSGroup`, and `SettingsListGroup`; do not introduce a second global settings navigation shell.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Guidance | `make guidance-check` | exit 0 |
| Previews | `make preview-check` | exit 0 with no preview compilation errors |
| Build | `make build-agent` | exit 0 |
| Tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'Settings.*Tests'` | selected settings tests pass |

## Suggested executor toolkit

- Use `macos-app-engineering` for native macOS settings-shell behavior.
- Use `swiftui-pro` for layout, state, and modifier-order review.
- Read `.agents/docs/build-and-test.md` before selecting narrower validation commands.

## Scope

**In scope**

- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsScrollableContent.swift`
- A new shared settings content-surface component under `Sources/UI/components/settings/` if needed.
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift` only to remove the embedded-path gutter inconsistency.
- Focused settings previews/tests if required.

**Out of scope**

- The Modes three-column drawer; implement that in Plan 070.
- Redesigning the global sidebar or `SettingsSection` taxonomy.
- Changing persistence, localization keys unrelated to layout, or window minimum size.
- A repository-wide visual rewrite of every settings component.

## Steps

### Step 1: Define the shared page-surface behavior

Create or extend one reusable container that owns this contract: `SettingsWindowBackground` remains the background owner; content receives a consistent top inset below toolbar/embedded chrome; scrollable content receives the existing 20-point horizontal gutter and bottom breathing room; the content frame expands to available width and height; and the container does not add local nested scroll views. Prefer extending `SettingsScrollableContent` or creating a thin wrapper around it. Do not add one-off `.padding(.top)` calls to individual tabs.

**Verify**: `make preview-check` → exit 0; settings previews compile without new warnings.

### Step 2: Apply the contract to toolbar and legacy chrome

Update `SettingsDetailChromeModifier` so toolbar-based and legacy/embedded destinations have the same logical content start position. The toolbar remains owned by `SettingsPage`; the content surface must not duplicate navigation buttons or titles. Keep macOS 15 fallbacks and macOS 26 toolbar behavior working.

**Verify**: `make preview-check && swift test --package-path Packages/MeetingAssistantCore --filter 'Settings.*Tests'` → both commands pass.

### Step 3: Remove the embedded Modes edge-to-edge path

Make `StylesSettingsTab` use the shared surface contract in both `embedded` and non-embedded modes. Preserve list row actions and selection. The Modes list group must have a visible outer gutter on both sides and bottom breathing room without changing internal `SettingsInlineList` row padding.

**Verify**: `make preview-check` → exit 0; `git diff --check` → exit 0.

### Step 4: Add width/height previews for the contract

Add previews for a representative settings page at normal and narrow widths. The preview must show the toolbar boundary, outer gutter, group surface, and scrollable content. Keep it deterministic and compile-checked.

**Verify**: `make preview-check` → all new previews compile.

## Test plan

- Add a layout test only if the repository has an established view-inspection pattern; otherwise use previews and existing settings tests.
- Verify Modes row selection, context-menu actions, and add/edit/delete callbacks remain unchanged.
- Verify no new nested whole-page `ScrollView` is introduced.

## Done criteria

- [ ] Toolbar and legacy settings routes have a consistent content start inset.
- [ ] Modes list content has a consistent outer gutter and does not touch usable page edges.
- [ ] Shared surface expands horizontally and vertically without fixed content width.
- [ ] `make preview-check`, `make guidance-check`, and `make build-agent` exit 0.
- [ ] No global sidebar taxonomy or persistence changes are made.
- [ ] `plans/README.md` status row is updated after implementation.

## STOP conditions

- The live `SettingsPage` chrome path differs materially from the excerpts above.
- Fixing the inset requires changing `SettingsWindowConfigurator` or AppKit window behavior.
- A tab requires a second scroll view to preserve existing behavior.
- The change would alter sidebar navigation or persisted settings behavior.
- Any verification fails twice after a reasonable correction.

## Maintenance notes

Future settings pages should use the shared surface instead of local outer padding. Reviewers should check that background, safe area, scroll container, and gutter have one owner. Plan 070 depends on this contract.
