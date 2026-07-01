# Plan 011: Merge Dashboard and History into Activity

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in "STOP conditions" occurs, stop and report instead of improvising. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a62d4a8e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Sources/UI/Models Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests App`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/010-consolidated-settings-routing-foundation.md`
- **Category**: direction / tech-debt
- **Planned at**: commit `a62d4a8e`, 2026-07-01

## Why this matters

`Dashboard` and `History` are product surfaces, not settings categories. Keeping them as separate settings-sidebar rows makes the window feel like a mixed app shell. Consolidating them under `Activity` reduces visible navigation count and gives users one place for "what happened in Prisma".

## Current state

- `SettingsSection.swift:23-30` puts `.transcriptions` and `.metrics` in primary sidebar sections.
- `MetricsDashboardSettingsTab.swift:24-50` owns dashboard routes and loads metrics.
- `TranscriptionsSettingsTab.swift:32-91` owns history list/detail routes and search synchronization.
- `TranscriptionsSettingsTab.swift:107-160` renders the history list with filters.
- `MetricsDashboardPages.swift:13-38` renders the dashboard index.
- `SettingsPage.swift:37-44` keeps separate navigation state for metrics and transcriptions.
- `SettingsPage.swift:303-320` only shows the history search field when selected section is `.transcriptions`.
- `App/MeetingAssistantApp.swift:147-152` falls back to opening `SettingsSection.transcriptions.rawValue` for history.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Activity/search tests | `./scripts/run-tests.sh --suite dev --file SettingsSectionTests --file SettingsSearchIndexTests --file MetricsDashboardNavigationTests --file TranscriptionsNavigationHistoryTests` | exit 0 |
| Preview coverage | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Full lane gate before push | `make build-test && make lint` | exit 0, or documented unrelated baseline failures |

## Scope

**In scope**:

- `SettingsSection.swift`
- `SettingsPage.swift`
- `SettingsSidebarView.swift` only if display grouping needs a label update
- New file under `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift`
- Existing `MetricsDashboardSettingsTab.swift` and `TranscriptionsSettingsTab.swift` only for initializer/search binding adjustments
- `SettingsSearchIndex.swift` and tests
- `App/MeetingAssistantApp.swift` only if history open routing needs `.activity`

**Out of scope**:

- Refactoring metrics storage or history loading performance.
- Redesigning transcription cards.
- Moving Activity out of the settings window.

## Git workflow

- Branch: `advisor/011-merge-dashboard-history-activity`
- Commit style: `refactor(settings): merge dashboard and history into activity`

## Steps

### Step 1: Create `ActivitySettingsTab`

Add `ActivitySettingsTab.swift` with an internal route enum:

```swift
public enum ActivitySettingsRoute: Hashable {
    case dashboard
    case history
}
```

The root should show a compact segmented picker or list-style switch between Dashboard and History. Reuse the existing views:

- dashboard: `MetricsDashboardSettingsTab(navigationState: ...)`
- history: `TranscriptionsSettingsTab(searchText:navigationHistory:)`

Do not duplicate dashboard/history UI. The new container owns only the Activity-level switch and routes.

**Verify**: `make build-agent` -> exit 0 after wiring temporary preview if needed.

### Step 2: Move the selected-section state to Activity

In `SettingsPage.swift`, replace separate top-level detail cases for `.metrics` and `.transcriptions` with `.activity` for visible navigation. Keep legacy cases resolving to Activity through plan 010's resolver.

Activity still needs the old child navigation states:

- `metricsNavigationState`
- `transcriptionsNavigationHistory`
- `transcriptionsSearchText`

Move these into the `ActivitySettingsTab` initializer if that keeps `SettingsView` smaller. If moving them would create awkward two-way toolbar binding, keep them in `SettingsView` for this plan and pass bindings down.

**Verify**: `./scripts/run-tests.sh --suite dev --file MetricsDashboardNavigationTests --file TranscriptionsNavigationHistoryTests` -> exit 0.

### Step 3: Preserve the history toolbar search behavior

The search field currently appears only when `selectedSection == .transcriptions && transcriptionsNavigationHistory.currentRoute == .list`. After consolidation it should appear when:

- selected visible section is `.activity`
- Activity child route is `.history`
- history route is `.list`

If the child route cannot be inspected cleanly from `SettingsView`, prefer keeping a small `@Binding var activeRoute: ActivitySettingsRoute` on `ActivitySettingsTab` rather than adding global state.

**Verify**: `make build-agent` -> exit 0.

### Step 4: Update sidebar and search mapping

Make the visible sidebar show `Activity` instead of separate Dashboard/History rows. Add localization keys:

- `settings.section.activity` = `Activity`
- Portuguese equivalent in `pt.lproj`

Update `SettingsSearchIndex`:

- `metrics.*`, `settings.section.metrics`, `settings.section.history`, `settings.transcriptions.*`, `transcription.qa.*` route to `.activity`.
- Existing searches for "dashboard", "history", and "transcriptions" should return Activity.

Update tests with representative cases.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests --file SettingsSearchIndexTests` -> exit 0.

### Step 5: Update history deep links

Update direct callers that open history so they use the new visible destination or the resolver path:

- `App/MeetingAssistantApp.swift:147-152`
- `App/AppDelegate/MenuBar.swift` if it still opens `.transcriptions`

If the UX requires opening the History child page rather than Activity dashboard, add a typed child route only inside settings navigation. Do not encode child routes as free-form strings unless there is already a local pattern for it.

**Verify**: `rg -n "SettingsSection\\.(metrics|transcriptions)\\.rawValue|openSettings\\(section: SettingsSection\\.(metrics|transcriptions)" App Packages/MeetingAssistantCore/Sources` -> no active call sites except compatibility tests or resolver tests.

### Step 6: Run the thermo-nuclear review and fix its blockers

Invoke `thermo-nuclear-code-quality-review` with this scope:

```text
Audit the Activity consolidation diff. Look for duplicated dashboard/history state, mixed ownership between SettingsView and ActivitySettingsTab, stringly child routing, file growth past maintainability limits, and any new conditionals that should be a small typed route model.
```

Fix every structural blocker. If the review says `ActivitySettingsTab` is just a pass-through wrapper with messy state leakage, either move route ownership fully into it or defer the plan as BLOCKED.

**Verify**: rerun all commands from "Commands you will need".

## Test plan

- Update `SettingsSectionTests` for visible order.
- Update `SettingsSearchIndexTests` for dashboard/history/transcription queries.
- Keep existing metrics/history navigation tests passing.

## Done criteria

- [ ] Visible sidebar has one Activity row instead of Dashboard and History rows.
- [ ] History menu/deep links still open a useful Activity/history surface.
- [ ] History search still appears only on the history list.
- [ ] No dashboard/history UI was copied.
- [ ] Thermo-nuclear review blockers fixed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Activity child routing requires changing persistence or transcription data models.
- The history search field becomes globally visible in unrelated settings pages.
- Consolidation pushes `SettingsPage.swift` over 700 lines without removing equivalent complexity elsewhere.

## Maintenance notes

Activity is an app surface inside the current settings window. If Prisma later gets a true main window, this page should be the first candidate to move out of Settings.
