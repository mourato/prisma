# Plan 014: Polish consolidated settings layout patterns

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in "STOP conditions" occurs, stop and report instead of improvising. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a62d4a8e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Sources/UI/components/design-system Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/011-merge-dashboard-history-activity.md`, `plans/012-merge-models-context-dictionary-intelligence.md`, `plans/013-merge-general-sound-permissions-system.md`
- **Category**: tech-debt / direction
- **Planned at**: commit `a62d4a8e`, 2026-07-01

## Why this matters

After sidebar consolidation, the remaining polish work is layout consistency: headers, subnavigation, toolbar accessories, and repeated helper copy. This plan makes the settings surface feel intentionally Mac-native instead of a stack of old tabs embedded under new labels.

## Current state

- `SettingsSidebarView.swift:21-45` uses two broad groups: `about.title` and `settings.title`.
- `SettingsSectionHeader.swift:24-47` provides the standard title/description/callout header.
- `ShortcutSettingsSection.swift:27-48` turns shortcut descriptions into popover-only helper copy.
- `SettingsPage.swift:303-337` shows toolbar accessories for meeting and integration capability toggles.
- `MeetingSettingsTab.swift:108-117` repeats the meeting shortcut description in both page header and shortcut section.
- `DictationSettingsTab.swift:51-58` uses shortcut copy as the Dictation page description.
- `EnhancementsSettingsTab.swift:60-67` uses Text & Context description while also showing context-specific sections.
- `AudioSettingsTab.swift` and `MeetingSettingsTab.swift` are above the preferred 600-line boundary.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Settings-focused tests | `./scripts/run-tests.sh --suite dev --file SettingsSectionTests --file SettingsSearchIndexTests --file SettingsSubpageNavigationStateTests --file MeetingSettingsNavigationStateTests --file AppDesignSystemAppearanceTests --file SettingsWindowLayoutStateEvaluatorTests` | exit 0 |
| Preview coverage | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Full lane gate before push | `make build-test && make lint` | exit 0, or documented unrelated baseline failures |

## Scope

**In scope**:

- `SettingsSidebarView.swift`
- `SettingsPage.swift`
- `SettingsSectionHeader.swift`
- `ShortcutSettingsSection.swift`
- consolidated container tabs from plans 011-013
- targeted child tab header parameters
- file decomposition for over-large settings tabs
- settings previews/tests

**Out of scope**:

- New visual branding.
- New design-system primitives unless an existing pattern cannot express the needed layout.
- Runtime behavior changes for recordings, transcription, AI, permissions, or integrations.

## Git workflow

- Branch: `advisor/014-polish-settings-layout-patterns`
- Commit style: `refactor(settings): polish consolidated settings layout`

## Steps

### Step 1: Rename sidebar grouping around real intent

After plans 011-013, the visible sidebar should be 7 rows. Replace vague grouping if needed:

- Product/workflow group: Activity, Dictation, Meetings, Assistant, Integrations
- Configuration group: Intelligence, System

Use localized section labels. If "Product" feels too abstract in UI, use "Prisma" for the first group and "Settings" for the second. Keep it short.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` -> exit 0.

### Step 2: Standardize subnavigation UI

Activity, Intelligence, and System should use the same internal navigation pattern. Prefer one of:

- segmented picker for 2-3 peer subareas
- `SettingsDrillDownButtonRow` list for subareas that open deeper pages

Do not mix custom buttons, nested sidebars, and segmented controls across the three consolidated pages without a reason.

**Verify**: `make preview-check` -> exit 0.

### Step 3: Remove repeated visible explanations

Audit each consolidated page for repeated copy in:

- page header description
- group header
- row subtitle
- popover/helper button

Keep one baseline explanation per cluster. Use popovers only for extra context, not duplicates.

Concrete likely edits:

- Dictation page header should describe dictation as a workflow, not repeat the shortcut section text.
- Meeting page should avoid repeating `settings.shortcuts.meeting_desc` in both header and shortcut group.
- Intelligence page should not show "Text & Context" as the whole-page description if Models and Dictionary are peers.

**Verify**: `rg -n "settings\\.shortcuts\\.meeting_desc|settings\\.shortcuts\\.header_desc|settings\\.text_context\\.description" Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings` -> each reused key has a clear reason; no same-key header/group duplication in one visible page.

### Step 4: Make toolbar accessories local and predictable

Review `SettingsPage.swift` capability toolbar logic. If meeting/integration toggles feel disconnected after consolidation, prefer moving those toggles into the page header or first group of the relevant page. Toolbars should stay focused on navigation/search.

Do not remove the toggles; only move presentation if it improves predictability.

**Verify**: `make build-agent` -> exit 0.

### Step 5: Keep large files from growing

Run:

```bash
for f in Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/*SettingsTab.swift; do wc -l "$f"; done | sort -nr
```

Any settings tab over 600 lines touched by plans 011-014 must either:

- shrink below 600 lines, or
- be split into colocated focused files with unique names, or
- include a PR note explaining why it remains above the preference and what follow-up issue handles it.

**Verify**: command above shows no touched file worsened without rationale.

### Step 6: Run the thermo-nuclear review and fix its blockers

Invoke `thermo-nuclear-code-quality-review` with this scope:

```text
Audit the full settings consolidation and polish diff from plans 010-014. Be extremely strict about whether the final UI/code is simpler than the old 12-tab setup. Flag redundant copy, wrapper views that do not reduce complexity, route conditionals in random places, files growing past healthy size, and missed opportunities to delete old legacy cases after compatibility is preserved.
```

Fix all critical and medium structural findings. If a finding cannot be fixed in this plan, update `plans/README.md` with a BLOCKED reason or create a GitHub issue if instructed by the operator.

**Verify**: rerun all commands from "Commands you will need".

## Test plan

- Settings section/search/navigation tests.
- Preview coverage for consolidated pages and child states.
- Build confidence with `make build-agent`.
- Full lane gate before push/merge: `make build-test` and `make lint`.

## Done criteria

- [ ] Sidebar has 7 visible destinations.
- [ ] Consolidated pages share one internal navigation pattern.
- [ ] No obvious repeated visible helper copy remains in the same viewport.
- [ ] Toolbar contains navigation/search or clearly justified page-level actions only.
- [ ] Touched settings files respect the 600-line preference or have documented decomposition rationale.
- [ ] Thermo-nuclear review blockers fixed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Visual polish starts changing recording/transcription behavior.
- The review finds the new 7-section taxonomy hides essential controls with no search/deep-link path.
- Fixing layout consistency requires a new design system larger than the duplicated code it replaces.

## Maintenance notes

This is the final quality pass. Do not use it to add new settings. It exists to make the reduced settings interface feel deliberate and maintainable.
