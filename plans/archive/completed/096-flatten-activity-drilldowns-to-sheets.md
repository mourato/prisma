# Plan 096: Flatten Activity drill-downs to sheets; localize History chrome

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
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardPages.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardPerformanceComponents.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/TranscriptionsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/TranscriptionConversationPage.swift \
>   Packages/MeetingAssistantCore/Sources/UI/Models/ActivitySettingsNavigationState.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ActivitySettingsNavigationStateTests.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/MetricsDashboardNavigationTests.swift
> ```

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/093-establish-settings-flatten-ia-and-expandable-row.md
- **Category**: migration
- **Planned at**: commit `bb6fbf79`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `yes` vs 094/095 content-wise; serialize writers
- **Reviewer required**: `yes` — deep links (`openActivityHistory`, metrics)
- **Rationale**: Activity has nested history stacks + metrics ViewModels
- **Escalate when**: Sheet presentation cannot host performance recording detail
  without losing state — stop and propose side panel instead

## Why this matters

Activity root still pushes four toolbar-driven destinations (History,
Performance, More Insights, Event Detail), plus nested stacks inside History
and Performance. B2 keeps **History** as the only Activity sub-destination
(menu bar + `NavigationService.openActivityHistory()`), moves analytics/detail
into sheets, and moves History search + conversation back **onto the History
surface** so global toolbar chrome can die in 097.

## Current state

```3:8:Packages/MeetingAssistantCore/Sources/UI/Models/ActivitySettingsNavigationState.swift
public enum ActivitySettingsRoute: Hashable, Sendable {
    case root
    case history
    case modelPerformance
    case moreInsights
    case eventDetail(MeetingCalendarEventSnapshot)
}
```

Root drill-downs: `ActivityDashboardDrillDownSection` in
`MetricsDashboardPages.swift` (~289–311).

Toolbar search appears when `isShowingHistoryList` (`ActivitySettingsNavigationState.swift:29-31`)
via `SettingsPage` binding `transcriptionsSearchText`.

Legacy: `.metrics` → `.modelPerformance`; `.transcriptions` → `.history`.

## Target shape

```
Activity root (SettingsFormPage)
├── Heatmap + upcoming events (unchanged)
├── Drill-down / buttons:
│   ├── Recording History → activeRoute = .history (only subpage)
│   ├── Model Performance → sheet
│   └── More Insights → sheet
└── Event card → sheet (event detail)

History (subpage)
├── In-page search field (relocated from toolbar)
├── Filters + list (unchanged)
└── Conversation → presented as sheet OR child with local back button
    (prefer sheet for B2 aggressiveness; if conversation needs persistent
    width, use local push with explicit Back — no global toolbar)

Metrics recording detail
└── Nested inside Performance sheet (sheet-from-sheet OK) or replace
    performanceRecording route with a second sheet level
```

Deep links:

- `openActivityHistory()` / `.transcriptions` → History subpage (unchanged)
- `.metrics` → Activity root **and** present Performance sheet (or open root
  with sheet auto-presented once — implement carefully to avoid re-present
  loops)

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Nav tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'ActivitySettingsNavigationStateTests\|MetricsDashboardNavigationTests\|SettingsSectionTests'` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Validate | `make validate-agent ARGS="--lane auto --base main"` | PASS |

## Suggested executor toolkit

- `macos-app-engineering`
- `accessibility-audit` if sheet focus issues appear
- Do not copy VoiceInk code; sheets already exist elsewhere in Meetings

## Scope

**In scope:**

- `ActivitySettingsTab.swift`, `MetricsDashboardPages.swift`,
  `MetricsDashboardSettingsTab.swift`, performance components as needed
- `ActivitySettingsNavigationState.swift` — shrink routes; keep `.history`
- `TranscriptionsSettingsTab.swift` — local search; conversation presentation
- `SettingsPage.swift` — stop owning transcriptions search field in toolbar
  for History (field moves into History); Activity back/forward may remain
  until 097 for History only
- Tests listed above
- Localization for any new sheet close labels if needed (prefer Cancel/Done
  existing keys)

**Out of scope:**

- Deleting History as a destination
- Folding History list into Form rows
- Modes
- Full toolbar removal (097)
- Changing metrics computation / ViewModels business logic beyond presentation

## Git workflow

- Branch: `advisor/096-flatten-activity-sheets`
- Commits: e.g. `refactor(settings): present Activity metrics in sheets`
- Do NOT push/PR unless asked

## Steps

### Step 1: Event Detail → sheet

On root, replace `activeRoute = .eventDetail` with `@State` / item-based
`.sheet`. Move `MetricsDashboardEventDetailPage` into the sheet. Remove
`.eventDetail` from `ActivitySettingsRoute` and metrics top-level routing for
events.

**Verify**: build; open event from upcoming list → sheet; dismiss returns to root
without toolbar back

### Step 2: More Insights → sheet

Same pattern for More Insights page content. Remove `.moreInsights` route.

**Verify**: build + metrics navigation tests updated

### Step 3: Model Performance → sheet (including recording detail)

Present Performance workspace in a sheet. Nested `performanceRecording` should
be either:

- a second sheet, or
- in-sheet navigation with a local back button inside the sheet

Remove `.modelPerformance` from `ActivitySettingsRoute`. Update legacy
`.metrics` destination to open Activity + present performance sheet (store a
one-shot flag on navigation state or `NavigationService` — prefer a field on
`ActivitySettingsNavigationState` like `pendingSheet: ...` cleared on present).

**Verify**:
```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'ActivitySettingsNavigationStateTests|MetricsDashboardNavigationTests|SettingsSectionTests'
```

### Step 4: Localize History chrome

- Move search UI from `SettingsPage` toolbar/legacy header into
  `TranscriptionsSettingsTab` list header.
- Ensure conversation has an explicit dismiss/back that does not require
  `SettingsPage.navigateBack`.
- Keep `activeRoute == .history` as the only Activity subpage; root↔history may
  still use `activityNavigationState` until 097, but History must also expose a
  visible Back to Activity control on the History header.

**Verify**: `rg -n "shouldShowTranscriptionsSearch|transcriptionsToolbarSearchField" Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift` → no History search ownership left (or only dead code removed)

### Step 5: Slim ActivitySettingsNavigationState

After steps 1–3, routes should be `.root | .history` only (plus optional
pending-sheet flags). Rewrite tests accordingly. Forward-route complexity for
metrics can die.

**Verify**: Activity nav tests pass; `rg -n "modelPerformance|moreInsights|eventDetail" Packages/MeetingAssistantCore/Sources/UI/Models/ActivitySettingsNavigationState.swift` → absent from enum

## Test plan

- Rewrite `ActivitySettingsNavigationStateTests` for root/history + sheet flags.
- Update `MetricsDashboardNavigationTests` for sheet-era routes or delete
  obsolete stack cases.
- Manual: menu bar Open History; search metrics; open performance recording;
  Reduce Motion sheet animation.

## Done criteria

- [ ] Activity routes are only root + history (plus ephemeral sheet state)
- [ ] Event / Insights / Performance use sheets
- [ ] History search is in-page
- [ ] Conversation dismissible without global toolbar
- [ ] Deep links still work
- [ ] Tests + `make build-agent` green
- [ ] `plans/README.md` → DONE

## STOP conditions

- Performance sheet cannot host filters + charts without unusable height — stop;
  consider `settingsSidePanel` full-height alternative and refresh plan.
- Removing `.metrics` deep link breaks external callers beyond settings — stop
  and preserve one-shot sheet presentation.
- Drift from plan 092 Activity Form index work since `bb6fbf79`.

## Maintenance notes

- 097 should only need Activity back for History↔root (or History local back
  makes even that optional).
- Reviewers: do not regress heatmap Form chrome from 092.
