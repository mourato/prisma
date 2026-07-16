# Plan 078: Replace the Modes split view with the VoiceInk-style editor drawer experience

> **Executor instructions**: Follow this plan step by step, in order. Read the
> complete plan before editing anything. Run every verification command and
> confirm the expected result before moving to the next step. Do not substitute
> a sheet, inspector, nested split view, AppKit panel, or another navigation
> pattern for the trailing overlay described here. If anything in the "STOP
> conditions" section occurs, stop and report — do not improvise. When the
> implementation, Full validation, and required review are complete, update
> this plan's status row in `plans/README.md`.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat bff804d7..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/ModeEditorDrawer.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorDetailView.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStylePromptEditorView.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/TriggerSelectionView.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleIconView.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppDesignSystem.swift \
>   Packages/MeetingAssistantCore/Sources/UI/Models/DictationStyleRoute.swift \
>   Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift \
>   Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings \
>   Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSubpageNavigationStateTests.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/DictationStylesSettingsViewModelTests.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppSettingsDictationStylesTests.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSidePanel.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleIconPickerPopover.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleTriggerSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleTriggerPickerPopover.swift \
>   plans/078-match-voiceink-mode-editor-drawer-experience.md \
>   plans/README.md
> ```
>
> If any in-scope file changed, compare the live implementation with the
> excerpts and invariants in "Current state" before continuing. If the nested
> split, draft, target, or save contracts no longer match, treat that as a STOP
> condition and ask for the plan to be refreshed.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none — this supersedes the presentation decisions from completed Plans 066, 067, 068, 070, 072, 074, 075, 076, and 077
- **Category**: direction
- **Planned at**: commit `bff804d7`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — panel presentation, editor draft lifetime, child navigation, focus restoration, triggers, and visual anatomy share the same SwiftUI state and must be changed serially in one isolated worktree.
- **Reviewer required**: `yes` — a thermo-nuclear review must clear all Critical and Medium findings, and a visual reviewer must compare the running Prisma surface against the locked VoiceInk reference before merge.
- **Rationale**: This replaces the presentation architecture of a primary Settings workflow and touches more than eight UI/test/resource files. It is not deterministic Low/Fast work.
- **Escalate when**: The live scope reaches persistence/runtime matching, the global Settings sidebar, concurrency, more than 300 added source lines without equivalent deletion, or any public API outside `MeetingAssistantCoreUI`; keep High/Full and ask the root orchestrator to rescope before proceeding.

## Why this matters

The current Prisma component is named `ModeEditorDrawer`, but the editor is
presented by a conditional nested `NavigationSplitView`. Opening it therefore
shrinks and reflows the Modes list inside the already split Settings window.
VoiceInk `v2.0-beta.2` instead keeps the list geometry stable and overlays a
400-point trailing panel with one coherent material surface, compact identity
header, grouped form, and fixed footer. This plan replaces the incorrect
presentation primitive and then aligns entry affordances, editor hierarchy,
trigger selection, motion, dismissal, keyboard behavior, and visual evidence
with that reference while preserving Prisma's stronger persistence, privacy,
accessibility, localization, and target-exclusivity contracts.

This is not a spacing-only cleanup. Do not retain the nested split and attempt
to disguise it with animation or styling.

## Locked reference and acceptance contract

The normative reference is VoiceInk tag `v2.0-beta.2`, commit
`ba32144fea4bc687b4f20e3bb03ec9719a401482`:

- Panel owner and activation: `VoiceInk/Modes/ModeView.swift:53-193`
  - <https://github.com/Beingpax/VoiceInk/blob/v2.0-beta.2/VoiceInk/Modes/ModeView.swift>
- Overlay geometry, material, dismissal, and motion:
  `VoiceInk/Views/Components/SidePanel.swift:3-100`
  - <https://github.com/Beingpax/VoiceInk/blob/v2.0-beta.2/VoiceInk/Views/Components/SidePanel.swift>
- Identity header, grouped form, fixed footer, Save/Delete/Cancel, and keyboard:
  `VoiceInk/Modes/ModeConfigFormView.swift:58-159,604-634`
  - <https://github.com/Beingpax/VoiceInk/blob/v2.0-beta.2/VoiceInk/Modes/ModeConfigFormView.swift>
- Inline trigger summary and picker popover:
  `VoiceInk/Modes/ModeTriggerSection.swift:19-91` and
  `VoiceInk/Modes/TriggerPickerPopover.swift:66-92`
  - <https://github.com/Beingpax/VoiceInk/blob/v2.0-beta.2/VoiceInk/Modes/ModeTriggerSection.swift>
  - <https://github.com/Beingpax/VoiceInk/blob/v2.0-beta.2/VoiceInk/Modes/TriggerPickerPopover.swift>

VoiceInk is GPL-3.0 and Prisma is MIT. Use the behavior and visual anatomy above
as a product specification only. Do not copy VoiceInk source, comments, or
non-trivial code structure verbatim. Implement the contract independently with
Prisma's components and naming.

The final Prisma experience must satisfy all of these invariants:

| Area | Required result |
|---|---|
| Presentation | A trailing SwiftUI overlay inside the Modes detail area; no sheet, inspector, nested split, extra window, or AppKit panel |
| Geometry | Default panel width is exactly 400 pt; the underlying Modes list never changes width or layout when the panel opens/closes |
| Coverage | The panel overlays only the Modes content/detail area and never covers or reconstructs the global Settings sidebar |
| Outside layer | Clear, non-dimming, no blur, no shadow, no rounded outer panel; clicking outside invokes the same cancel/discard path as Close |
| Surface | One continuous sidebar-style material/tint across header, body, and footer, with subtle 1 pt leading/trailing separators and a solid Reduce Transparency fallback |
| Motion | Open/close uses trailing move plus opacity for 0.32 s; Reduce Motion uses opacity-only ease-out for 0.12 s; reversal is state-driven with no timers |
| Header | 36 pt visual icon button, editable mode name inline, text-backed icon-only Close button; no duplicate Name/Icon fields in the form |
| Body | Native grouped `Form`, not a scroll view containing stacked `DSGroup` cards |
| Footer | Fixed Delete-or-Cancel leading action and prominent Save/Create trailing action; `Command-Return` saves |
| Triggers | Selected apps/sites stay visible in the form; Add opens a focused 340 x 440 search popover; trigger editing never replaces the whole panel |
| Prompt | Prompt editing may replace the panel body as a child route; Escape/back returns to the mode form before a second Escape dismisses the panel |
| Transaction | Close, outside click, and Escape discard the unsaved draft; Save persists; nested trigger edits remain draft-only; delete remains confirmed |
| Focus | New/edit focuses the name; prompt/trigger search focuses its field; closing restores keyboard and accessibility focus to the initiating mode row |
| Accessibility | Visible Add/Edit actions, text-backed icon buttons, semantic selected/conflict states, Reduce Motion/Transparency support, and predictable VoiceOver order |

## Current state

Confirm these facts before editing:

- `ModesSettingsTab.swift:19-33` conditionally replaces the list-only tree with
  a nested `NavigationSplitView`. This is the primary defect. The file must not
  contain `NavigationSplitView` after this plan.
- `ModesSettingsTab.swift:51-62` transitions only the detail route. It does not
  animate or stabilize the list-to-split structural replacement.
- `StylesSettingsTab.swift:41-55` wraps the complete list in `DSGroup` and puts
  Add at the bottom. `:75-121` uses single-click selection plus double-click or
  a context action to edit. The final list needs a top-level visible Add action
  and an always-visible Edit action per mode while preserving selection,
  Delete-key behavior, context menu, and focus restoration.
- `ModeEditorDrawer.swift:57-72` is only a header/scroll/footer layout wrapper;
  it does not present a drawer. `:61-70` owns a generic `ScrollView`, preventing
  the editor body from becoming a native grouped `Form`.
- `DictationStyleEditorDetailView.swift:94-125` supplies Save/Cancel/Delete,
  while `:132-241` repeats Name/Icon below the header and stacks several
  `DSGroup` cards. The local `@State` draft fields and `saveDraft()` validation
  are correct and must be retained.
- `TriggerSelectionView.swift:39-59` is a full child page. It owns temporary
  targets and applies them when Back/Escape is used. The filtering, conflict,
  duplicate, website-normalization, app-icon, and accessibility behavior are
  reusable, but the full-page route is not.
- `DictationStylePromptEditorView.swift:17-41` is a valid child-panel concept;
  preserve its focused editor and back semantics, but adapt it to the new
  drawer anatomy.
- `DictationStylesSettingsViewModel.swift:72-137` constructs, clears, saves,
  and deletes drafts. Do not replace this persistence boundary or autosave.
- `SettingsMotion.swift:3-15`, `VisualEffectView.swift:4-20`,
  `SettingsWindowBackground.swift:8-97`, and
  `AppDesignSystem.swift:110-179,286-320` provide the reusable motion,
  material, semantic-color, accessibility, and layout-token foundations.
- `SettingsSubpageNavigationStateTests.swift:61-102` and
  `DictationStylesSettingsViewModelTests.swift:18-115` are the existing route
  and draft regression patterns.

## Reuse -> extend -> create decision

Apply this decision exactly:

1. **Reuse** `DictationStylesSettingsViewModel`,
   `DictationStyleEditorDraft`, `DictationStyleRoute`,
   `SettingsSubpageNavigationState`, `VisualEffectView`,
   `AppDesignSystem`, `SettingsMotion`, `DictationStyleIconView`,
   `AppIconView`, `EnhancementsModelPicker`, checkbox save semantics,
   localization keys, target normalization, and conflict validation.
2. **Extend** `SettingsMotion` and `AppDesignSystem.Layout` with named side-panel
   values. Extend `ModeEditorDrawer` to own the VoiceInk-like three-zone anatomy
   while leaving actual presentation to a new overlay component.
3. **Create** one generic `SettingsSidePanel.swift`, one visual
   `DictationStyleIconPickerPopover.swift`, and narrowly named trigger section
   and popover views only because no equivalent reusable components exist.
4. **Remove** the obsolete full-page `TriggerSelectionView.swift` after its
   reusable logic has moved. Do not keep two trigger editors.
5. **Do not create** a second view model, persistence model, navigation stack,
   AppKit controller, window, or third-party dependency.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Worktree state | `git status --short --branch` | isolated feature worktree; no unrelated changes |
| Scope preview after complete implementation diff | `make scope-check-agent ARGS="--dry-run --base main"` | exit 0; selects Full once the complete in-scope diff exists |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests|SettingsSearchIndexTests|LocalizationKeyIntegrityTests'` | all selected tests pass |
| Preview coverage | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Guidance/ledger | `make guidance-check` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0, no whitespace errors |
| Final Full gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | exit 0 with strict lint and build-test PASS |

Do not repeatedly run the Full gate during iteration. Use focused tests,
`make preview-check`, and `make build-agent`; run the Full gate once after the
visual and code reviews have no unresolved blocking findings.

## Suggested executor toolkit

- Use `macos-app-engineering` for the overlay, grouped form, native controls,
  focus, materials, and preview structure.
- Use `swiftui-pro` for state ownership, transitions, accessibility, and
  performance review.
- Use `benchmarking` only to verify the locked VoiceInk tag and behavior; never
  edit the sibling VoiceInk checkout.
- Use `testing-xctest` when extending route/draft tests.
- Use `delivery-workflow` for High/Full validation and evidence reporting.
- After implementation, dispatch `thermo-nuclear-code-quality-review` with the
  Prisma review profile from `.agents/docs/prisma-review-profile.md`.

## Scope

**In scope — modify only as required:**

- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/ModeEditorDrawer.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorDetailView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStylePromptEditorView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/TriggerSelectionView.swift` — migrate reusable logic, then delete
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleIconView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppDesignSystem.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Models/DictationStyleRoute.swift`
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift` — only if a draft helper is strictly necessary; no persistence changes
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSubpageNavigationStateTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/DictationStylesSettingsViewModelTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppSettingsDictationStylesTests.swift`
- `plans/README.md` and this plan's status only at final handoff

**In scope — create with these exact responsibilities:**

- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSidePanel.swift` — generic overlay presentation, surface, outside dismissal, geometry, motion, accessibility fallbacks, and previews
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleIconPickerPopover.swift` — visual SF Symbol/emoji choice only
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleTriggerSection.swift` — selected target summary/chips and Add affordance inside the grouped form
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleTriggerPickerPopover.swift` — focused search, app/site candidate selection, conflict feedback, and deterministic previews

**Out of scope — do not modify:**

- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift`,
  `SettingsSidebarView.swift`, `SettingsSection.swift`, or global Settings
  taxonomy. The overlay belongs inside Modes, not around the global shell.
- `DictationStyle` storage shape, `AppSettingsStore` persistence, migrations,
  active-app/URL runtime matching, prompt construction, context capture, model
  residency, or AI provider behavior.
- The one-target-per-mode invariant. Preserve immediate conflict feedback and
  repeat conflict validation on Save.
- Any VoiceInk file, copied GPL implementation, third-party UI dependency,
  `NSPanel`, `NSWindow`, sheet, inspector, or additional `NavigationSplitView`.
- Unrelated Settings screens or broad design-system restyling.

## Git workflow

- Implement in one explicitly isolated feature worktree; never edit product
  source from the base/orchestrator checkout.
- Suggested branch: `feat/078-voiceink-mode-drawer`.
- Preserve unrelated changes. Do not use destructive Git commands.
- Use atomic Conventional Commits. Recommended checkpoints:
  1. `feat(settings): add reusable trailing side panel`
  2. `refactor(settings): present mode editor as overlay drawer`
  3. `feat(settings): align mode form and trigger popover`
  4. `test(settings): cover mode drawer experience`
  5. `fix(settings): resolve mode drawer review findings` when required
- Run the focused test/preview/build checks before each logical commit. Do not
  push or open a PR unless the operator requests it.

## Steps

### Step 1: Establish the baseline and lock the target behavior

1. Run the drift check and `git status --short --branch`.
2. Read every current-state file listed above. Do not start from the old plans'
   claim that VoiceInk uses a detail destination; that claim is obsolete for
   `v2.0-beta.2`.
3. Read the four locked VoiceInk files from the URLs above or with read-only
   `gh api` calls. Record the tag commit in the implementation handoff.
4. Run the focused tests and `make preview-check` before editing. Record any
   existing failure separately; do not attribute it to this plan.
5. Record the plan's declared classification as High/Full. Do not run the scope
   dry-run yet: a fresh worktree has no product diff to classify. Run it after
   Step 2 creates the first source slice.

**Verify**:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests|SettingsSearchIndexTests|LocalizationKeyIntegrityTests'
make preview-check
```

Expected: focused tests and preview check pass. If the baseline fails twice,
STOP and report the exact test/check name without proceeding into UI edits.

### Step 2: Add the reusable trailing overlay primitive

Create `SettingsSidePanel.swift` as a generic `ViewModifier`, exposed through a
single `View.settingsSidePanel(...)` extension. The modified view is always the
stable underlying content; the builder produces only the overlay panel. Its
public or package-internal API must accept:

- presentation state (`isPresented` or an optional item);
- `onDismiss`, called by the clear outside layer;
- a width defaulting to `AppDesignSystem.Layout.modeEditorPanelWidth`;
- `@ViewBuilder` panel content.

Do not create a second root-content builder. In the modifier's
`body(content:)`, `content` is the underlying Modes list.

Implement this exact structure:

```swift
ZStack(alignment: .trailing) {
    underlyingContent

    if isPresented {
        clearDismissLayer
        panelContent
            .frame(width: resolvedPanelWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(sidebarMaterialSurface)
            .overlay(leadingSeparator, alignment: .leading)
            .overlay(trailingSeparator, alignment: .trailing)
            .transition(sidePanelTransition)
            .zIndex(1)
    }
}
.animation(sidePanelAnimation, value: isPresented)
```

Requirements:

- Add `modeEditorPanelWidth = 400` to `AppDesignSystem.Layout`.
- Add named `sidePanelAnimation(reduceMotion:)` and
  `sidePanelTransition(reduceMotion:)` APIs to `SettingsMotion`:
  - normal: `.smooth(duration: 0.32)` plus trailing move combined with opacity;
  - Reduce Motion: `.easeOut(duration: 0.12)` plus opacity only.
- Use `VisualEffectView(material: .sidebar, blendingMode: .behindWindow)` plus
  the existing semantic panel/canvas overlay. With Reduce Transparency, render
  `settingsCanvasBackground` instead of vibrancy.
- Use semantic separator colors with increased-contrast support. No shadow,
  dimming, corner radius, backdrop overlay color, or click-through.
- Resolve width as 400 pt at supported Settings sizes. Only clamp when the
  actual Modes content is narrower than 400 pt; never force horizontal scroll.
- Implement the outside layer with a semantic `Button` or equivalent control,
  not an unlabeled `onTapGesture`. Hide the clear layer from VoiceOver and the
  keyboard focus chain; closing remains available through the labeled Close
  button and Escape.
- Add deterministic previews: closed, open, Reduce Motion, Reduce Transparency,
  light, dark, and a narrow container.

**Verify**:

```bash
make preview-check
make build-agent
```

Expected: both commands exit 0; the open preview shows a trailing 400 pt panel
over stable sample content. Keep the plan's declared High/Full classification;
do not ask a partial diff to reclassify the final change.

### Step 3: Replace the nested split without changing draft persistence

Refactor `ModesSettingsTab` so its root always renders the same list tree. Apply
the new side-panel modifier/container around that tree. The route state controls
only whether the overlay exists and which panel content it displays.

Required state flow:

1. Add/Edit calls `viewModel.prepareEditor(for:)`.
2. Store `.editor(styleID:)` in the existing route state.
3. `SettingsSidePanel` becomes presented whenever `currentRoute != nil`.
4. The panel switch renders `.editor` or `.promptEditor`. Remove
   `.triggerSelection` from `DictationStyleRoute` and from the switch.
5. Close, outside click, and Escape call one shared `dismissEditor` method that:
   - captures the explicit return-focus target;
   - clears `viewModel.editorDraft`;
   - returns the route to root;
   - restores keyboard and accessibility focus as defined below.
6. Save and confirmed Delete use their existing view-model operations, then
   invoke the same route/focus cleanup without clearing already-persisted data.
7. Opening the prompt route keeps the same draft. Back/Escape returns to
   `.editor(styleID:)`; it must not dismiss the whole panel on the first Escape.

Use one explicit focus target enum for keyboard and accessibility focus, for
example `.addButton` and `.style(UUID)`. Define the outcomes exactly:

- Open Add -> remember `.addButton`; Cancel/Close/outside/Escape -> focus Add.
- Save Create -> make `DictationStylesSettingsViewModel.saveStyle` return the ID
  it persisted; close and focus `.style(returnedID)`.
- Open Edit -> remember `.style(existingID)`; Save/Cancel -> focus that row.
- Confirm Delete -> focus Add, because the deleted row no longer exists.

Update view-model tests to assert that create returns the new persisted ID and
edit returns the existing ID. This is a return-value seam only; do not change
persistence or autosave behavior.

Do not place `.transition` on the underlying list and do not change its identity
when presentation changes. Remove every `NavigationSplitView`,
`navigationSplitViewColumnWidth`, empty detail placeholder, and split-only
layout branch from `ModesSettingsTab`.

Update route tests to cover:

- root -> editor -> root;
- editor -> prompt -> editor -> root;
- reopen a different mode after dismissal;
- rapid route changes leave only the latest route active;
- no trigger-selection route remains.

**Verify**:

```bash
rg -n 'NavigationSplitView|navigationSplitViewColumnWidth|emptyDetailPlaceholder' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift
swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests'
make preview-check
```

Expected: `rg` returns no matches; all selected tests pass; previews compile.

### Step 4: Make Add and Edit immediately discoverable without losing Prisma behavior

Refactor `StylesSettingsTab` to preserve the main list geometry and reduce the
nested-card appearance:

- Put a visible labeled Add button beside the Modes list/section heading, not
  below the complete list. Use `Button("…", systemImage: "plus", action:)`.
- Render one low-density mode surface per item with approximately 12 pt vertical
  separation. Reuse `DSCard(style: .settings)` or the nearest existing settings
  surface; do not wrap the complete list and every row in redundant cards.
- Keep icon, mode name, target count, target icons, Markdown/language/base-prompt
  metadata, context menu, single-click selection, `onDeleteCommand`, and focus
  restoration.
- Add an always-visible labeled Edit button to every row. Do not hide Edit when
  metadata is absent. The existing double-click may remain as a shortcut, but
  it cannot be the only visible edit affordance.
- Remove the current row-level `.accessibilityElement(children: .ignore)`,
  because it would hide Edit. Combine only the non-interactive summary subview;
  keep Edit and the context menu as separate contained children in predictable
  VoiceOver and keyboard order.
- Keep destructive Delete in the context menu and in the confirmed editor
  footer. Do not add an unconfirmed visible Delete button to the row.
- Ensure the row's Edit and context controls remain independently clickable and
  keyboard reachable; do not cover them with the AppKit click-capture overlay.

Add populated and empty previews. The populated preview must contain at least
one default mode, one app-target mode, and one website-target mode.

**Verify**:

```bash
make preview-check
make build-agent
```

Expected: both exit 0; Add and Edit are visible in the previews without opening
a context menu or double-clicking.

### Step 5: Rebuild `ModeEditorDrawer` as a three-zone panel anatomy

Keep `SettingsSidePanel` responsible for presentation. Make
`ModeEditorDrawer` responsible only for the content anatomy:

```text
VStack(spacing: 0)
  identity-or-child header
  content that owns its own scrolling and expands to available height
  fixed optional footer
```

Editor header requirements:

- The mode icon is a 36 x 36 labeled button with a circular/subtle semantic
  surface. It opens `DictationStyleIconPickerPopover`.
- The name is a plain inline `TextField` bound directly to local draft state,
  using a 16 pt-equivalent semantic headline/semibold hierarchy and predictable
  first focus.
- Close is created with a text-backed system-image button and rendered
  icon-only. It invokes the shared cancel path.
- Remove the separate header title and remove Name/Icon fields from the form.

Child header requirements:

- A labeled Back button, child title, and no editor footer unless the child has
  its own explicit commit action.
- Escape calls Back when a child is active.

Footer requirements:

- Existing non-default mode: confirmed Delete left, Save right.
- New mode: Cancel left, Create/Save right.
- Default mode: no Delete.
- Save/Create is `.borderedProminent`, disabled at minimum when the trimmed
  name is blank, and has
  `.keyboardShortcut(.return, modifiers: .command)`.
- Do not duplicate target/conflict validation merely to disable the button.
  Keep existing target/conflict validation in `saveDraft()` unless a pure
  existing helper can be reused.
- Header and footer have separators but do not paint independent competing
  material cards. The continuous material comes from `SettingsSidePanel`.

Remove the `ScrollView` from `ModeEditorDrawer`; each body owns its correct
scrolling primitive.

**Verify**:

```bash
rg -n 'ScrollView' Packages/MeetingAssistantCore/Sources/UI/components/settings/ModeEditorDrawer.swift
rg -n 'keyboardShortcut\(\.return, modifiers: \.command\)' Packages/MeetingAssistantCore/Sources/UI/components/settings/ModeEditorDrawer.swift
make preview-check
```

Expected: the first `rg` returns no matches; the second returns the Save/Create
shortcut; previews compile.

### Step 6: Convert the editor body to a native grouped form without losing fields

In `DictationStyleEditorDetailView`, retain every existing local state field,
`currentDraft`, normalization, conflict validation, Delete confirmation, and
`saveDraft()`. Change only presentation and wiring.

The body inside `ModeEditorDrawer` must be:

```swift
Form {
    // Triggers for non-default modes, or default-mode hint
    // Behavior and prompt
    // Context resources
    // Enhancements model
}
.formStyle(.grouped)
.scrollContentBackground(.hidden)
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

Required section order and contents:

1. **Triggers** for non-default modes: selected target summary/chips, Add
   popover, and validation feedback. For the default mode, show the existing
   default-mode explanation instead.
2. **Behavior**: prompt row, post-processing enabled, Markdown output, replace
   base prompt, and output language.
3. **Context Resources**: accessibility text, selected text at start with its
   description, clipboard, OCR, and sensitive-data redaction.
4. **Enhancements model**: the existing model picker and refresh behavior.

Save-backed booleans remain checkbox-style controls; do not convert them to
immediate-effect switches. Do not duplicate section titles in cards inside the
grouped form. Use `LabeledContent`, native `Picker`, existing picker components,
and semantic text styles. Preserve all English/Portuguese localization keys or
replace both locales together and delete orphaned keys.

**Verify**:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests|LocalizationKeyIntegrityTests|SettingsSearchIndexTests'
make preview-check
make build-agent
```

Expected: all selected tests pass; preview/build exit 0; every persisted editor
field remains reachable.

### Step 7: Implement a visual icon picker popover

Create `DictationStyleIconPickerPopover.swift` and reuse
`DictationStyleIconCatalog.recommendedSymbols` plus existing emoji detection.

Required behavior:

- Adaptive grid of 44 pt icon buttons with 10 pt spacing.
- Selected item has a semantic accent fill/stroke and a non-color selected
  indication accessible to VoiceOver.
- Choosing a recommended symbol updates the binding and closes the popover.
- Provide a small emoji text field that accepts one extended grapheme cluster;
  valid emoji updates the binding and closes on Add/Return.
- Preserve arbitrary legacy SF Symbol strings already stored. If the current
  value is not in the recommended catalog, show it as the first current-value
  option when `NSImage(systemSymbolName:accessibilityDescription:)` can resolve
  it; never rewrite it merely by opening the picker.
- Invalid or empty input shows localized inline feedback and does not mutate the
  binding.
- Initial keyboard focus and all buttons have localized labels/help.
- Popover target size: minimum 280 pt, ideal 320 pt, maximum 340 pt; content
  scrolls vertically when needed.

Do not add emoji persistence or a global emoji manager. The selected emoji is
already persisted in `iconSymbol`.

**Verify**:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests'
make preview-check
```

Expected: tests pass; previews cover symbol selected, emoji selected, legacy
symbol, invalid emoji, light, and dark states.

### Step 8: Replace the trigger child page with an inline section and picker popover

Create `DictationStyleTriggerSection.swift` and
`DictationStyleTriggerPickerPopover.swift`. Move, do not duplicate, the reusable
logic from `TriggerSelectionView`.

`DictationStyleTriggerSection` requirements:

- Bind directly to the editor's local `targets` array. These mutations remain
  draft-only until the parent Save action.
- Show an empty state when no target exists.
- Show selected apps with `AppIconView`, display name, and removable action.
- Show websites with a globe icon, normalized display value, and removable
  action.
- Put a visible labeled Add button in the section header. Opening it triggers
  app-catalog loading and presents the picker.
- Every removal has a localized text-backed accessibility label.

`DictationStyleTriggerPickerPopover` requirements:

- Fixed target geometry of 340 x 440 pt; clamp height only if the window is
  genuinely shorter.
- Search field at the top, divider, then a lazy scroll list.
- Focus search on appear without a fixed delay.
- Trim the query and rank deterministic results: exact app name, name prefix,
  name contains, bundle prefix, bundle contains; tie-break with
  `localizedStandardCompare`.
- When the normalized query looks like a website, show one Add/Remove website
  candidate row above app results.
- Selected app/site rows show a checkmark and toggle removal. Conflicting
  targets show the owning mode name when available and remain disabled.
- Preserve the existing one-target-per-mode check at add time and the second
  validation pass in `saveDraft()`.
- Cover loading, empty, search match, website candidate, selected, conflict,
  and narrow-height previews.

After the new section and popover compile:

- remove `.triggerSelection` from `DictationStyleRoute`;
- remove trigger route rendering from `ModesSettingsTab`;
- delete `TriggerSelectionView.swift`;
- confirm no second trigger editor remains.

**Verify**:

```bash
rg -n 'triggerSelection|TriggerSelectionView' Packages/MeetingAssistantCore/Sources Packages/MeetingAssistantCore/Tests
swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|AppSettingsDictationStylesTests|DictationStylesSettingsViewModelTests'
make preview-check
make build-agent
```

Expected: `rg` returns no matches; selected tests pass; preview/build exit 0.

### Step 9: Harden dismissal, keyboard, focus, and transaction semantics

Verify and, where testable, encode these state transitions:

- Close -> clear draft -> close panel -> focus initiating row.
- Outside click -> the exact same path as Close.
- Escape in main form -> the exact same path as Close.
- Escape in prompt child -> return to main form, preserving draft.
- Second Escape -> discard draft and close panel.
- Command-Return in main form -> validate, persist, close, restore focus.
- Delete -> confirmation -> delete only on confirmation -> close and restore
  sensible list focus.
- Cancel deletion -> remain in editor with unchanged draft.
- Trigger popover dismissal -> keep local target edits in the draft but do not
  persist them.
- Save -> persist current prompt, triggers, context policy, model, and behavior.
- Switching from one mode to another must never reuse stale local view state;
  preserve or add stable `.id` semantics only at the editor identity boundary,
  not around the entire list or panel.

Extend `DictationStylesSettingsViewModelTests` only for model/draft transitions.
Extend route tests for editor/prompt/root transitions. Do not introduce brittle
tests that parse Swift source text.

**Verify**:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests'
make build-agent
```

Expected: all selected tests pass and build exits 0.

### Step 10: Build an integrated visual-validation matrix

The existing isolated previews are insufficient because they do not prove that
the list remains stable under the real overlay. Add deterministic previews or a
private preview harness that renders the actual Modes list and editor panel
together. Do not add preview-only behavior to production state unless it is an
internal initializer with a harmless default.

Required states:

- closed list and open editor at 900 x 640;
- open editor at the minimum supported Settings geometry;
- expanded width;
- new mode and existing mode;
- prompt child;
- trigger popover open;
- Delete confirmation owner state where previewable;
- light and dark;
- Dynamic Type accessibility size;
- Reduce Motion;
- Reduce Transparency;
- validation error;
- empty and populated lists.

The open/closed previews must use identical underlying list width. The panel
must measure 400 pt at supported geometry. If the executor has Xcode preview
rendering tools, capture PNG evidence outside the repository. Otherwise run the
debug app from the isolated worktree with `make run` and capture equivalent
screenshots manually. Use only deterministic preview/fixture data in captured
images; never expose real transcripts, prompts, app targets, credentials, or
personal identifiers. Do not commit generated screenshots unless explicitly
requested.

**Verify**:

```bash
make preview-check
make build-agent
make run
```

Expected: preview/build exit 0; `make run` builds and launches the isolated
worktree's Debug `Prisma.app`; the reviewer can inspect every required state.

### Step 11: Perform the blocking visual acceptance review

This step cannot be replaced by compilation. A separate read-only
`design-reviewer` agent, or a human reviewer designated by the operator, must
compare the running Prisma implementation side by side with the locked VoiceInk
behavior. The writing implementer may prepare evidence but cannot self-approve.

Create a non-repository evidence directory and launch the isolated build:

```bash
mkdir -p /tmp/prisma-plan-078-visual
make run
```

Store privacy-safe screenshots as
`/tmp/prisma-plan-078-visual/01-list-closed.png` through the numbered matrix
states below. Store the verdict in
`/tmp/prisma-plan-078-visual/visual-acceptance.md`, one line per matrix row:
`<number> | PASS/FAIL | evidence filename | concise observation`. Do not add
this directory to Git. If no separate visual reviewer is available, STOP and
report that the blocking approval is pending.

Run this manual matrix and record PASS/FAIL evidence in the handoff:

1. Open Modes with the global Settings sidebar visible. Record the list width.
2. Open Add. Confirm the panel overlays only Modes, is 400 pt, and the list did
   not resize, move, or reconstruct.
3. Close with X, outside click, and Escape in separate attempts. Confirm the
   same discard semantics and symmetric motion.
4. Repeat with Reduce Motion and Reduce Transparency enabled.
5. Edit an existing mode. Confirm inline icon/name, grouped form, fixed footer,
   Command-Return Save, and focus restoration.
6. Open prompt editing. Confirm first Escape returns to the form and the second
   closes the panel.
7. Open trigger Add. Confirm the 340 x 440 focused popover, deterministic search,
   app/site selection, conflict display, and draft-only behavior before Save.
8. Resize to minimum and expanded widths. Confirm no horizontal scrolling,
   clipping, third column, or list starvation.
9. Check light/dark, large text, keyboard-only traversal, and VoiceOver order.
10. Confirm there is no dimming, shadow, rounded outer edge, duplicate identity
    fields, nested card stack, sheet, inspector, or nested split.

Any FAIL is a blocking defect. Fix it before thermo review and rerun the affected
matrix row. Do not mark the plan DONE based only on `make preview-check`.

### Step 12: Review, fix, validate, and hand off

1. Run thermo-nuclear review with `.agents/docs/prisma-review-profile.md`.
2. Fix every Critical and Medium finding. Make a separate review-fix commit when
   appropriate.
3. Rerun focused tests, preview, build, and the affected visual matrix rows.
4. Run the scope dry-run against the complete implementation diff and confirm
   that it selects Full. If it selects Fast despite the final file count and
   presentation-architecture change, keep the declared High/Full lane and note
   the classifier mismatch in the handoff.
5. Run `make guidance-check` because the plan ledger changes.
6. Run the Full lane once with `--no-reuse`.
7. Update `plans/README.md` and this plan status only after code review, visual
   review, and Full validation pass.

**Verify**:

```bash
git diff --check
swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests|AppSettingsDictationStylesTests|SettingsSearchIndexTests|LocalizationKeyIntegrityTests'
make preview-check
make build-agent
make scope-check-agent ARGS="--dry-run --base main"
make guidance-check
make validate-agent ARGS="--lane full --no-reuse --agent"
git status --short
```

Expected: every command exits 0; Full result is PASS; `git status` contains only
the intended plan implementation/ledger changes before commit and is clean
after the final atomic commit.

## Test plan

Update tests before or alongside the owning behavior:

### `SettingsSubpageNavigationStateTests.swift`

- root -> editor;
- editor -> prompt -> editor;
- editor -> root and reopen another ID;
- rapid route replacement leaves the latest editor ID;
- trigger route no longer exists.

Use the existing tests in this file as the structural pattern. Do not test
SwiftUI pixels here.

### `DictationStylesSettingsViewModelTests.swift`

- `clearEditor()` discards without persisting; Close/outside/Escape wiring is a
  SwiftUI integration guarantee and stays in the manual matrix unless an
  existing UI-inspection seam can test it without parsing source;
- Save persists and clears;
- create returns the newly persisted ID and edit returns the existing ID;
- reopening another style gets a fresh draft;
- confirmed Delete removes non-default and preserves default;
- prompt/target draft values survive child navigation until Save.

Use the existing setup/reset isolation pattern and do not introduce global
state leakage.

### `AppSettingsDictationStylesTests.swift`

- emoji and legacy symbol round-trip unchanged;
- app/site normalization and duplicate prevention remain unchanged;
- cross-mode target conflict remains enforced;
- context-source policy and enhancements selection still round-trip through
  Save.

### SwiftUI previews and manual review

- Previews cover presentation, geometry, appearance, motion, transparency,
  form, icon picker, trigger picker, validation, and child routes.
- Manual review covers motion, stable underlying geometry, focus restoration,
  outside click, keyboard shortcuts, VoiceOver, and actual material rendering.

## Done criteria

All items are mandatory:

- [ ] `ModesSettingsTab.swift` contains no `NavigationSplitView`, split-column width, or empty-detail placeholder.
- [ ] Opening/closing the editor does not change the underlying list's width, layout, or identity.
- [ ] The drawer is a trailing SwiftUI overlay with a 400 pt design-system width at supported Settings geometry.
- [ ] The overlay covers only Modes content; the global Settings sidebar remains stable.
- [ ] Normal motion is trailing move+opacity at 0.32 s; Reduce Motion is opacity-only at 0.12 s.
- [ ] Reduce Transparency uses a solid semantic fallback.
- [ ] Header contains inline icon/name/Close and the form contains no duplicate Name/Icon fields.
- [ ] Body is a native grouped `Form`; redundant `DSGroup` card stacking is removed from the drawer.
- [ ] Footer remains fixed and exposes confirmed Delete or Cancel plus prominent Save/Create with Command-Return.
- [ ] Trigger selection is inline plus popover; `.triggerSelection` and `TriggerSelectionView.swift` are gone.
- [ ] Prompt child navigation preserves draft and uses two-stage Escape behavior.
- [ ] Close, outside click, and Escape discard unsaved changes; Save persists; Delete remains confirmed.
- [ ] Add and Edit are visible without double-click or context menu.
- [ ] Existing mode fields, target exclusivity, context/privacy defaults, localization, and runtime matching remain unchanged.
- [ ] Integrated previews cover every state listed in Step 10 and `make preview-check` exits 0.
- [ ] The manual matrix in Step 11 is recorded as PASS by a visual reviewer.
- [ ] Thermo review has no unresolved Critical or Medium findings.
- [ ] Focused tests, `make build-agent`, `make guidance-check`, and the no-reuse Full gate all pass.
- [ ] No files outside Scope are modified.
- [ ] `plans/README.md` and this plan status are updated only after all gates pass.

## STOP conditions

Stop and report; do not improvise if:

- The current nested split/draft/target code no longer matches "Current state".
- Matching the behavior appears to require changing `SettingsPage.swift`, the
  global Settings sidebar, AppKit window ownership, or persistence/runtime
  matching.
- The only proposed solution uses a sheet, inspector, nested split,
  `NavigationSplitView`, `NSPanel`, `NSWindow`, horizontal scrolling, or a
  third-party UI dependency.
- A trigger change would weaken one-target-per-mode exclusivity or persist
  changes before parent Save.
- Closing the panel cannot use the same cancel path for X, outside click, and
  Escape.
- The list still moves/reflows when the panel opens after two reasonable fixes.
- The panel cannot remain 400 pt at supported Settings geometry without
  clipping or changing the global window minimum.
- Any persisted mode field becomes unreachable or changes its default.
- A focused test, preview check, build, or Full gate fails twice after a
  reasonable correction.
- Visual review cannot be performed. Do not claim parity from source inspection
  or preview compilation alone.
- More than 300 source lines are added without meaningful deletion/replacement,
  suggesting the old architecture is being retained alongside the new one.

## Maintenance notes

- `SettingsSidePanel` is generic infrastructure, but do not adopt it elsewhere
  during this plan. A later consumer must independently justify overlay
  semantics, outside dismissal, and transaction behavior.
- Keep panel visibility, child route, and editor draft as separate concepts.
  Presentation changes must not become persistence changes.
- Any future mode field belongs in the grouped form and must round-trip through
  `DictationStyleEditorDraft`; do not add another modal or child route unless
  the interaction genuinely needs the full panel body.
- Trigger types must continue to define normalization, display, duplicate
  identity, conflict behavior, and runtime matching together.
- Reviewer hotspots: list identity during presentation, stale draft reuse,
  outside-dismiss data loss, popover focus, fixed-footer overlap, material under
  Reduce Transparency, keyboard shortcut conflicts, and accessibility order.
- Plans 066–077 remain historical evidence of the previous direction. Do not
  reopen or edit them; this plan deliberately supersedes their presentation
  architecture while preserving their valid persistence/accessibility work.
