# Plan 097: Retire Settings toolbar back/forward navigation chrome

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat bb6fbf79..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsScrollableContent.swift \
>   Packages/MeetingAssistantCore/Sources/Common/Config/AppIdentity.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/
> ```
>
> Also confirm 094–096 are DONE (or explicitly waived) before removing chrome:
> Meetings must not need back/forward; System children must have local back;
> Activity History must have in-page search + local back.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: plans/094-flatten-meetings-into-single-form-page.md,
  plans/095-flatten-system-settings-onto-general.md,
  plans/096-flatten-activity-drilldowns-to-sheets.md
- **Category**: migration
- **Planned at**: commit `bb6fbf79`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — final chrome cutover
- **Reviewer required**: `yes` — window chrome + accessibility + macOS 15/26
- **Rationale**: Touches Settings shell for all sections; High risk Full lane
- **Escalate when**: Capability toggles have no acceptable in-page home; or
  macOS 26 toolbar title must stay but ControlGroup removal breaks layout

## Why this matters

After 094–096, global back/forward and History search no longer have jobs.
Leaving the ControlGroup ships a permanently disabled or misleading chrome
(especially on Modes, where it was already a no-op). VoiceInk beta has **no**
toolbar history. This plan removes navigation chrome and relocates remaining
toolbar accessories (capability toggles) onto their pages.

## Current state (pre-094–096; verify live after those land)

`SettingsPage.swift`:

- `usesToolbarChrome` — macOS 26+ `.toolbar` vs legacy `safeAreaInset` bar
- `settingsToolbarContent` — navigation ControlGroup + optional search +
  capability toggles (~152–171)
- `navigateBack` / `navigateForward` / `canNavigateBack` / `canNavigateForward`
  (~384–469)
- Legacy/Tahoe bars duplicate the same controls (~247–290)

`AppIdentity.settingsToolbarIdentifier` may only matter if AppKit probes the
toolbar — check callers before deleting.

## Target chrome after this plan

| Element | Fate |
|---|---|
| Back/forward ControlGroup | **Remove** (toolbar + legacy + tahoe) |
| Transcriptions search in chrome | **Already moved** in 096 — delete leftovers |
| Capability toggles (Meetings / Assistant / Integrations) | **Move** into each tab’s Form header or first Section |
| Section `navigationTitle` (macOS 26) | **Keep** optional — title-only toolbar is OK |
| Sidebar toggle (legacy when sidebar hidden) | **Keep** |
| Modes drawer | Unchanged |

Prefer title-only toolbar (or legacy title strip) over deleting all chrome if
macOS 26 `NavigationSplitView` looks empty without `.navigationTitle`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Grep dead nav | `rg -n "navigateBack\|navigateForward\|canNavigateBack\|toolbarNavigationControlGroup\|legacyNavigationHistoryButton" Packages/MeetingAssistantCore` | no product hits |
| Tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSectionTests\|ActivitySettingsNavigationStateTests\|SettingsSearchIndexTests'` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Preview | `make preview-check` | exit 0 or documented baseline |
| Validate | `make validate-agent ARGS="--lane auto --base main"` | PASS |

## Suggested executor toolkit

- `macos-app-engineering` + `accessibility-audit` for focus after chrome removal
- `apple-design` only if motion around capability toggle relocation needs polish

## Scope

**In scope:**

- `SettingsPage.swift` — remove nav chrome; simplify toolbar/legacy headers
- Capability toggle UI relocated into:
  - `MeetingSettingsTab.swift`
  - `AssistantSettingsTab.swift`
  - `IntegrationsSettingsTab.swift`
  (reuse existing `capabilityToolbarAccessory` view body — move, don’t fork)
- Tests that asserted toolbar navigation — update/delete
- Docs in macos-app-engineering details: “no Settings history toolbar”
- `plans/README.md`

**Out of scope:**

- Redesigning Modes drawer geometry / `ignoresSafeArea` (Scenario A — separate)
- Changing sidebar taxonomy
- Removing `navigationTitle`
- Plan 083 visual matrix expansion (may run after; not blocking)

## Git workflow

- Branch: `advisor/097-retire-settings-toolbar-navigation`
- Commits: e.g. `refactor(settings): remove toolbar back-forward and relocate capability toggles`
- Do NOT push/PR unless asked

## Steps

### Step 0: Preconditions gate

Confirm:

```bash
rg -n "MeetingSettingsNavigationState|meetingNavigationState" Packages/MeetingAssistantCore/Sources || true
rg -n "case \\.permissions|case \\.protectedApps" Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/SystemSettingsTab.swift || true
rg -n "modelPerformance|moreInsights|eventDetail" Packages/MeetingAssistantCore/Sources/UI/Models/ActivitySettingsNavigationState.swift || true
rg -n "transcriptionsToolbarSearchField|shouldShowTranscriptionsSearch" Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift || true
```

Expected: Meetings nav gone; System permissions/protectedApps gone from route
enum; Activity enum without metrics/event cases; History search not owned by
SettingsPage. If not, STOP — finish 094–096.

### Step 1: Relocate capability toggles

Move the meetings/assistant/integrations enable controls from
`capabilityToolbarAccessory` into each tab’s Form (near existing capability
disable overlays). Preserve accessibility labels and immediate switch semantics
(plan 090).

Remove toolbar/legacy accessory branches.

**Verify**: build; each of the three tabs shows its toggle without window
toolbar accessory

### Step 2: Remove back/forward chrome

Delete:

- `toolbarNavigationControlGroup`
- `legacyNavigationHistoryButton` usages
- `navigateBack` / `navigateForward` / `canNavigateBack` / `canNavigateForward`
- Any Tahoe embedded duplicates

Keep sidebar toggle + title material as needed for macOS 15.

**Verify**: grep command in Commands table → clean

### Step 3: Simplify Activity History root back

If History still uses `activityNavigationState` for root↔history, ensure the
**only** user-visible back is the in-page control from 096. Optionally replace
remaining `goBack` API usage with a direct `activeRoute = .root` from that
button — no forward stack.

**Verify**: Activity nav tests pass; no forward-route tests remain unless still
needed for conversation (prefer none)

### Step 4: Guidance + previews

Update macos-app-engineering Settings notes: global Settings history toolbar is
retired; use expandable / sheets / side panel / local back.

Refresh `SettingsToolbarChromePreview` / related previews so they don’t expect
nav buttons.

**Verify**: `make guidance-check` (if docs touched); `make preview-check`

## Test plan

- Remove obsolete tests that encode toolbar back/forward for Meetings/System.
- Keep deep-link tests (History, models, etc.).
- Manual matrix: macOS 15 legacy header + macOS 26 toolbar title-only; Modes
  drawer; Meetings expandable; System Models local back; Activity sheets +
  History search.

## Done criteria

- [ ] No back/forward controls in Settings chrome
- [ ] Capability toggles live on their pages
- [ ] History search not in SettingsPage chrome
- [ ] Grep for nav helpers is clean
- [ ] Focused tests + `make build-agent` green
- [ ] `plans/README.md` → DONE for 097; note B2 sequence complete

## STOP conditions

- 094–096 preconditions fail
- Removing ControlGroup breaks `NavigationSplitView` layout on macOS 26 in a
  way that requires a new chrome system — stop and report with screenshots
- Capability toggle relocation would duplicate controls already on-page — dedupe
  instead of shipping two toggles

## Maintenance notes

- Scenario A (drawer over titlebar via `ignoresSafeArea`) remains optional and
  independent after B2.
- Plan 083 visual gates should be refreshed after this lands if still TODO.
- Reviewers: verify VoiceOver still reaches capability toggles; verify Escape
  still dismisses Modes panel.
