# Plan 071: Normalize fluid configuration groups and responsive rows

> **Executor instructions**: Follow this plan step by step. Run every verification command before moving to the next step. If a STOP condition is reached, stop and report it; do not improvise. This plan standardizes group width and responsive content; it does not create the Modes drawer.
>
> **Drift check (run first)**: `git diff --stat 2fc835f8..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSGroup.swift Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSCard.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsInlineList.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorDetailView.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/TriggerSelectionView.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: Plan 069
- **Category**: tech-debt
- **Planned at**: commit `2fc835f8`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: Medium/Full
- **Parallelizable**: no — shared design-system changes affect multiple settings tabs.
- **Reviewer required**: yes — visual regressions can be broad.
- **Rationale**: This is a cross-component layout contract and must preserve group semantics.
- **Escalate when**: More than the listed design-system/settings files require changes or any group must change persistence behavior.

## Why this matters

`DSGroup` and `SettingsListGroup` expand their outer cards, but some nested content remains at intrinsic width. In the mode editor this makes Behavior full width while Context Sources and Dictation Model appear narrower. Every configuration group should occupy 100% of its available page/container width while internal rows adapt to resizing. Preserve the distinction between `DSGroup` for composed cards and `SettingsListGroup` for row lists.

## Current state

- `DSGroup.swift:72-77` applies `frame(maxWidth: .infinity)` to the card and outer group.
- `SettingsListGroup.swift:84-99` applies a full-width card and owns list row padding/separators.
- `StylesSettingsTab.swift:44-58` wraps the Modes list in `DSGroup`, while `SettingsInlineList(containerStyle: .plain)` does not provide an outer card itself.
- `DictationStyleEditorDetailView.swift:92-202` uses an unconstrained vertical stack inside a local `ScrollView`; its identity row contains a fixed 220-point icon column at lines 103-131.
- `TriggerSelectionView.swift:40-56` has a local scroll view and `minWidth: 380`, a hard minimum rather than a fully adaptive layout.
- `SettingsScrollableContent.swift:18-26` is the existing width-filling settings content pattern.

`SettingsListGroup` owns list row spacing, separators, and row padding; callers must not add redundant local dividers or row padding. Use `DSGroup` for composed content, cards, pickers, and action clusters. Preserve `AppDesignSystem` tokens.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Previews | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests|SettingsSearchIndexTests'` | selected tests pass |
| Full validation | `make validate-agent ARGS="--lane full"` | exit 0, or documented baseline failure only |

## Suggested executor toolkit

- Use `macos-app-engineering` for shared settings component boundaries.
- Use `swiftui-pro` for flexible stacks, layout priorities, and `ViewThatFits` decisions.

## Scope

**In scope**

- `DSGroup.swift`
- `DSCard.swift` only if its sizing contract must be corrected.
- `SettingsListGroup.swift`
- `SettingsInlineList.swift`
- `DictationStyleEditorDetailView.swift`
- `TriggerSelectionView.swift`
- `StylesSettingsTab.swift`
- Related previews and focused UI/model tests.

**Out of scope**

- Global Settings sidebar or navigation shell.
- Moving the editor into a drawer; Plan 070 owns that.
- Labels, localization meaning, persistence, or runtime matching.
- Mechanical `frame(maxWidth: .infinity)` on controls that should remain compact.

## Steps

### Step 1: Define the group width contract

Implement this contract in shared components: group/card surface fills the proposed width; header fills the same width; content keeps existing card padding; compact controls may remain intrinsic width but their containing row fills the group; no component requires a fixed page width. If `DSGroup` already satisfies the outer contract, add only missing inner constraints or a small reusable modifier. Keep `SettingsListGroup` as the canonical list container.

**Verify**: `make preview-check` → existing `DSGroup` and `SettingsListGroup` previews compile and show full-width cards.

### Step 2: Normalize the Modes list surface

Ensure the Modes list group and `SettingsInlineList` fill the page surface while preserving row behavior. Add Mode remains trailing-aligned. Keep the list as one grouped surface, not separate row cards.

**Verify**: `make preview-check && git diff --check` → both pass.

### Step 3: Make editor sections width-fluid

Ensure the editor stack and every `DSGroup` use available width. Replace the fixed 220-point icon column with a flexible identity layout that can collapse or stack at narrow widths. Keep name and icon controls accessible. For Behavior, Context Sources, Dictation Model, and Targets, allow wrapping, bounded trailing controls, and no hard-coded page widths. Use `layoutPriority`, vertical fixed sizing, `ViewThatFits`, or a stacked fallback only where previews demonstrate need. Do not add horizontal scrolling.

**Verify**: `make preview-check` → editor previews compile at approximately 420, 640, and 900 points without horizontal clipping.

### Step 4: Make trigger selection responsive

Remove or reduce `minWidth: 380` unless proven necessary. Stack the website field and Add button when needed. Make app result rows full width. Preserve any bounded inner result scroll view without introducing a second whole-page scroll view.

**Verify**: `make preview-check && swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests'` → both pass.

### Step 5: Extract a responsive-row helper only if duplication is proven

Only after Steps 2–4, extract a shared helper if the same responsive behavior appears in at least two surfaces. Keep it small and design-system-owned; do not create a generic utilities module for one caller.

**Verify**: `make build-agent` → exit 0; no new file exceeds the project’s preferred 600-line limit.

## Test plan

- Add previews for wide, normal, and narrow widths for `DSGroup`, Modes list, editor, and trigger selection.
- Preserve existing mode persistence and target tests.
- Add view-inspection tests only if an established repository facility exists.
- Check compact controls remain compact while containing groups expand.

## Done criteria

- [ ] All touched configuration group surfaces fill their container width.
- [ ] Context Sources and Dictation Model no longer shrink to intrinsic width.
- [ ] Modes list has one full-width grouped surface with consistent outer gutter.
- [ ] Editor and trigger layouts adapt without horizontal scrolling/clipping.
- [ ] `SettingsListGroup` row ownership remains intact.
- [ ] Focused tests, previews, build, and Full validation pass.
- [ ] No persistence/runtime behavior changes.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

- A group cannot fill width without changing an unrelated settings tab.
- A control requires a fixed width larger than the supported settings container.
- The fix requires changing design-system colors/materials rather than layout.
- A new abstraction would have only one caller and no clear extension path.
- Any verification command fails twice after a reasonable correction.

## Maintenance notes

New sections should use `SettingsListGroup` for row lists and `DSGroup` for composed content. Reject local page-edge padding, local dividers inside `SettingsListGroup`, and fixed page widths. Demonstrate width behavior in previews before accepting new sections.
