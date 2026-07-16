# Plan 024: Align Settings controls with native VoiceInk beta patterns

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report;
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless a reviewer tells you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 6e68d1ef..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/design-system Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Sources/UI/pages/settings .agents/skills/swiftui-patterns/SKILL.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> meaningful mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt / direction
- **Planned at**: commit `6e68d1ef`, 2026-07-08

## Why this matters

The recent Settings menu-picker pass removed broad accent tint but then added a
custom `DSMenuSelect` surface for some controls. Compared with VoiceInk
`v2.0-beta.2`, that is the wrong default direction for Settings: the reference
uses native `Form`, `Section`, `LabeledContent`, and plain `Picker` controls
without local neutral tint or custom field chrome. Prisma should keep its
existing settings architecture, but move ordinary settings rows closer to that
native control anatomy. The sidebar is explicitly out of scope for this phase.

## Current state

- VoiceInk beta reference checked for this plan:
  - Repository/tag: `https://github.com/Beingpax/VoiceInk/tree/v2.0-beta.2`
  - Local benchmark copy: `/tmp/voiceink-v2.0-beta.2`, tag `v2.0-beta.2`, commit `ba32144`.
- VoiceInk Settings uses a native form structure:
  - `/tmp/voiceink-v2.0-beta.2/VoiceInk/Views/Settings/SettingsView.swift:29-31`:
    ```swift
    Form {
        Section {
            LabeledContent("Primary Shortcut") {
    ```
  - `/tmp/voiceink-v2.0-beta.2/VoiceInk/Views/Settings/SettingsView.swift:289-296`:
    ```swift
    private func shortcutModePicker(binding: Binding<RecordingShortcutManager.Mode>) -> some View {
        Picker("", selection: binding) {
            ForEach(RecordingShortcutManager.Mode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .labelsHidden()
        .fixedSize()
    }
    ```
  - `/tmp/voiceink-v2.0-beta.2/VoiceInk/Views/Settings/SettingsView.swift:150-171` shows ordinary menu-style settings as native `Picker`, with `.pickerStyle(.menu)` only where needed.
- VoiceInk customizes `Menu` mostly for action menus, not ordinary value pickers:
  - `/tmp/voiceink-v2.0-beta.2/VoiceInk/Views/AI Models/CloudModelCardView.swift:148-159` uses `Menu` plus `.menuStyle(.borderlessButton)` and `.menuIndicator(.hidden)` for an ellipsis action menu.
- Prisma already has the right native-like container to extend:
  - `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift:30-90` owns row structure, separators, and card-backed settings lists.
- Prisma currently has two menu abstractions:
  - `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSMenuPicker.swift:30-37` wraps native `Picker`, `.labelsHidden()`, `.pickerStyle(.menu)`, and optional width.
  - `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSMenuSelect.swift:30-68` draws a custom `Menu` label with manual padding, background, rounded stroke, chevron, and `.buttonStyle(.plain)`.
- `DSMenuSelect` is already used in ordinary Settings shortcut rows:
  - `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSShortcutControlsRow.swift:52-66` uses `DSMenuSelect` for activation mode and preset key.
- `DSMenuSelect` is also used in analytics/dashboard filters:
  - `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardPerformanceComponents.swift` uses it for filter and leaderboard sort controls.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Picker/control inventory | `rg -n "DSMenuPicker|DSMenuSelect|Picker\\(|\\.pickerStyle\\(\\.menu\\)|Menu\\(" Packages/MeetingAssistantCore/Sources/UI -g '*.swift'` | Lists all settings/control call sites to classify |
| SwiftUI previews | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Scoped gate | `make scope-check` | exit 0, or documented unrelated baseline failures |
| Guidance validation, only if `.agents` changes | `make guidance-check` | exit 0 |

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSMenuPicker.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSMenuSelect.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSShortcutControlsRow.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift`
- Settings page/tab controls under `Packages/MeetingAssistantCore/Sources/UI/pages/settings/`
- Settings-only shared components under `Packages/MeetingAssistantCore/Sources/UI/components/settings/`
- `.agents/skills/swiftui-patterns/SKILL.md`, only if the component policy changes

**Out of scope**:

- `SettingsSidebarView.swift` and any sidebar grouping, selection, icon, or navigation style.
- Settings taxonomy, route names, deep-link behavior, and search routing.
- Business logic for recording, transcription, post-processing, shortcuts, storage, providers, or metrics.
- Copying VoiceInk source code or importing VoiceInk visual identity.
- Replacing Prisma's whole settings shell with `Form`.

## Git workflow

- Branch: `advisor/024-native-settings-controls`
- Commit style: `refactor(settings): align controls with native menu patterns`
- Keep commits atomic. Do not push or open a PR unless instructed.

## Steps

### Step 1: Classify every Settings menu/control call site

Run the inventory command and classify each result into one of these buckets:

1. **Ordinary settings value picker**: a row selects one persisted setting value.
   Use native `DSMenuPicker` or direct `Picker` inside row anatomy.
2. **Peer mode selector**: segmented or tab-like choices, such as visual styles.
   Keep `.pickerStyle(.segmented)` where it expresses peer state.
3. **Action menu**: commands like edit/delete/template/ellipsis.
   Use `Menu` with action-menu styling; do not route through value-picker components.
4. **Dense analytic filter**: dashboard/leaderboard filters where a compact custom
   field may be justified.
   Keep only if a native picker does not fit the layout after visual review.

Document this classification in the PR description or implementation notes.

**Verify**: The inventory command exits 0 and every `DSMenuSelect` usage has a written keep/remove decision.

### Step 2: Revert ordinary Settings rows from `DSMenuSelect` to native picker anatomy

Update `DSShortcutControlsRow` first. Its current `DSMenuSelect` usage is an
ordinary value picker, and VoiceInk beta uses native shortcut-mode pickers in
`LabeledContent` rows. Replace those controls with `DSMenuPicker` or direct
`Picker` using:

- `.labelsHidden()`
- `.pickerStyle(.menu)` when direct `Picker` is used
- `.fixedSize()` or existing width constraints only where layout requires it
- no `.tint(.secondary)`
- no custom background/stroke/chevron

Do not change the shortcut model, bindings, defaults, recorder behavior, or
localization keys.

**Verify**: `make preview-check` -> exit 0.

### Step 3: Decide whether `DSMenuSelect` still earns its place

After Step 2, inspect remaining `DSMenuSelect` usages.

- If only dense analytics filters use it, either keep it and rename/document it
  as a dashboard/filter-specific control, or move it nearer to the metrics UI if
  it is not a general design-system primitive.
- If no call sites remain, delete `DSMenuSelect.swift` and its preview.
- If ordinary Settings rows still use it, stop and justify why a native picker
  cannot work there before proceeding.

The default preferred outcome is: ordinary Settings rows use native picker
anatomy; dashboard filters may keep a field-like component only as an explicit
exception.

**Verify**:
`rg -n "DSMenuSelect" Packages/MeetingAssistantCore/Sources/UI -g '*.swift'`
returns only justified dashboard/filter call sites, or returns no matches if the
component was removed.

### Step 4: Normalize row anatomy around `SettingsListGroup`

For ordinary settings rows touched by this plan, prefer the same structure:

```swift
HStack(alignment: .center, spacing: 12) {
    SettingsTitleWithPopover(title: "localized.title".localized, helperMessage: optionalHelper)
    Spacer()
    DSMenuPicker(selection: binding, width: optionalWidth) { ... }
}
```

Use `Text` instead of `SettingsTitleWithPopover` when there is no helper. Let
`SettingsListGroup` own separators and vertical row padding. Do not add local
`Divider()` or row padding inside `SettingsListGroup`.

Do not convert composed surfaces like model cards, tables, installed app
pickers, or metrics leaderboards into `SettingsListGroup` just for uniformity.

**Verify**:
`rg -n "Divider\\(\\)|\\.padding\\(\\.vertical" Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings -g '*.swift'`
and inspect only touched files; no new local dividers/padding should appear
inside `SettingsListGroup` rows.

### Step 5: Preserve accent only where it is semantic

Confirm this plan does not reintroduce broad accent tint. Accent remains valid
for:

- active selection
- primary action buttons
- destructive/error/success/status colors
- intentional highlight icons

Accent should not be applied to broad containers or neutral menu rows.

**Verify**:
`rg -n "\\.tint\\(AppDesignSystem\\.Colors\\.accent\\)|\\.tint\\(\\.secondary\\)" Packages/MeetingAssistantCore/Sources/UI -g '*.swift'`
shows no new broad Settings container tint and no neutral menu tint.

### Step 6: Update guidance only after the implementation choice is final

If Step 3 changes the policy, update
`.agents/skills/swiftui-patterns/SKILL.md` so future agents follow the new rule:

- In Settings, ordinary menu-value controls should use native picker anatomy
  (`DSMenuPicker` or direct `Picker`) with no neutral tint.
- `DSMenuSelect` is not a generic Settings control. It is either removed or
  limited to dense dashboard/filter surfaces with an explicit reason.
- Do not apply broad accent tint to settings containers.

**Verify**: `make guidance-check` -> exit 0.

## Test plan

- Run `make preview-check` after control/layout changes.
- Run `make build-agent` after the final source edit.
- Run `make scope-check` as the final scoped gate.
- If `.agents/skills/swiftui-patterns/SKILL.md` changes, run `make guidance-check`.
- Manual visual QA in the Settings window:
  - Shortcut mode/preset controls look enabled and native, not gray-disabled.
  - Ordinary Settings menu pickers do not inherit system blue/accent tint.
  - Dashboard filters remain compact and readable if they keep a custom field.
  - Primary/destructive/status controls keep their intended color treatment.
  - Sidebar visuals and behavior are unchanged.

## Done criteria

- [ ] Sidebar files and sidebar behavior are untouched.
- [ ] Ordinary Settings value pickers use native picker anatomy.
- [ ] `DSMenuSelect` is removed, relocated, or limited to justified dense filter surfaces.
- [ ] No `.tint(.secondary)` is used to neutralize menu pickers.
- [ ] No broad `.tint(AppDesignSystem.Colors.accent)` is applied to Settings containers.
- [ ] Touched settings rows let `SettingsListGroup` own separators and vertical row padding.
- [ ] `make preview-check`, `make build-agent`, and `make scope-check` have been run and results recorded.
- [ ] `make guidance-check` has been run if agent guidance changed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- The requested visual target requires changing `SettingsSidebarView.swift` or Settings route/taxonomy code.
- A native picker cannot reproduce an existing shortcut/settings behavior without changing the underlying model.
- Removing or relocating `DSMenuSelect` forces broad changes outside Settings or metrics/dashboard filters.
- The code at the "Current state" excerpts has drifted enough that the plan no longer maps to the implementation.
- Verification fails twice after reasonable scoped fixes.

## Maintenance notes

This plan intentionally treats VoiceInk beta as a design reference, not code to
copy. The durable rule is native-first: draw custom controls only when the
surface is not an ordinary settings row and the custom control pays for itself
in density or clarity. Reviewers should be strict about preventing another
generic wrapper from becoming the default just to compensate for a local tint or
layout issue.
