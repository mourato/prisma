# Plan 073: Harden the settings safe-area contract

> **Executor instructions**: Follow this plan in order. Run each verification
> command before continuing. Modify only the files in Scope. Stop and report
> instead of improvising when a STOP condition occurs.
>
> **Drift check**: `git diff --stat f9f1db2c..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsScrollableContent.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `f9f1db2c`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: Medium/Full
- **Parallelizable**: no — this is shared settings chrome.
- **Reviewer required**: yes — every settings tab can be affected.
- **Rationale**: The code change is localized but changes the vertical layout contract globally.
- **Escalate when**: The fix requires changing AppKit window configuration, toolbar ownership, or sidebar taxonomy.

## Why this matters

The current toolbar path reserves content space with a hard-coded 44-point top padding, while the legacy path uses `safeAreaInset`. This can drift when toolbar height, accessibility scaling, or macOS chrome changes. The Modes implementation also needs the same contract as every other settings tab. This plan makes the content boundary explicit and reusable.

## Current state

- `SettingsPage.swift:17` defines `LayoutConstants.contentChromeVerticalInset = 44`.
- `SettingsPage.swift:520-533` applies `.padding(.top, ...)` for toolbar chrome and `safeAreaInset` only for legacy chrome.
- `SettingsScrollableContent.swift:16-35` owns the scroll view, 20-point horizontal gutter, and bottom padding.
- `StylesSettingsTab.swift` has both embedded and non-embedded presentation paths.

Preserve `NavigationSplitView`, `SettingsWindowBackground`, `SettingsScrollableContent`, and existing design-system tokens. Do not solve this by adding local top padding to Modes.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Previews | `make preview-check` | exit 0 |
| Guidance | `make guidance-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'Settings.*Tests'` | selected tests pass |

## Scope

**In scope**

- `SettingsPage.swift`
- `SettingsScrollableContent.swift`
- `StylesSettingsTab.swift` only where needed to use the shared surface.
- Representative settings previews/tests.

**Out of scope**

- Modes pane architecture; Plan 074.
- Drawer transitions; Plan 075.
- Persistence, localization, and global sidebar taxonomy.

## Steps

### Step 1: Replace fixed chrome padding with one shared inset contract

Use one shared surface/container contract for toolbar and legacy chrome. Prefer `safeAreaInset(edge: .top)` or an equivalent chrome-owned inset over a literal 44-point content padding. The toolbar/navigation controls must remain owned by `SettingsPage`, and the content must not duplicate them.

**Verify**: `make preview-check` → exit 0.

### Step 2: Apply the contract to embedded settings content

Ensure `StylesSettingsTab` uses the same outer gutter and vertical breathing room when embedded. Preserve `SettingsInlineList` row padding and actions; only the page surface should own the outer margin.

**Verify**: `make preview-check && git diff --check` → both pass.

### Step 3: Add normal/narrow previews

Add deterministic previews showing toolbar boundary, first content row, horizontal gutters, and bottom breathing room at representative widths. Include the macOS 15-compatible path where applicable.

**Verify**: `make preview-check && make guidance-check` → both pass.

## Done criteria

- [ ] No toolbar content start depends on a raw 44-point padding constant.
- [ ] Toolbar and legacy paths have equivalent content boundaries.
- [ ] Embedded Modes content has the same outer gutter as other settings pages.
- [ ] Existing sidebar/navigation behavior is unchanged.
- [ ] Previews, guidance, build, and focused tests pass.
- [ ] `plans/README.md` is updated.

## STOP conditions

- The live toolbar API cannot expose a reliable safe-area boundary.
- A tab needs a second whole-page scroll view.
- The fix changes window sizing or sidebar taxonomy.
- Any verification fails twice after a reasonable correction.

## Maintenance notes

Future settings pages must consume this surface contract. Reviewers should reject local top-padding fixes and duplicate background/safe-area ownership.
