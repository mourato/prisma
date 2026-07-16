# Plan 010: Establish the consolidated settings routing foundation

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in "STOP conditions" occurs, stop and report instead of improvising. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat a62d4a8e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Sources/UI/Models Packages/MeetingAssistantCore/Sources/Infrastructure/Services/NavigationService.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against live code before proceeding.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt / direction
- **Planned at**: commit `a62d4a8e`, 2026-07-01

## Why this matters

Prisma still exposes 12 settings sidebar entries. The target reduction is 7 visible destinations: `Activity`, `Dictation`, `Meetings`, `Assistant`, `Integrations`, `Intelligence`, and `System`. Before moving content, create a route contract so old deep links, search results, and recording-indicator actions resolve predictably instead of adding ad-hoc branches during each consolidation.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift:5-17` defines 12 cases: `metrics`, `dictation`, `assistant`, `integrations`, `meetings`, `transcriptions`, `general`, `models`, `vocabulary`, `enhancements`, `audio`, `permissions`.
- `SettingsSection.swift:23-39` exposes all 12 through `primarySections` and `settingsSections`.
- `SettingsPage.swift:90-103` converts `NavigationService.requestedSettingsSection` directly with `SettingsSection(rawValue:)`.
- `SettingsPage.swift:375-498` hardcodes subnavigation support with repeated `if selectedSection == ...` checks.
- `SettingsPage.swift:503-525` switches directly from sidebar section to the current tab view.
- `SettingsSearchIndex.swift:120-174` maps localization keys to the old visible sections.
- `NavigationService.swift:48-52` opens a settings section by raw `String`.
- Existing tests: `SettingsSectionTests.swift`, `SettingsSearchIndexTests.swift`, `SettingsSubpageNavigationStateTests.swift`, `MetricsDashboardNavigationTests.swift`, `MeetingSettingsNavigationStateTests.swift`.

Repo conventions to preserve:

- User-facing text must use localization keys and both `en.lproj` and `pt.lproj`.
- Settings UI should reuse `SettingsSection`, `SettingsSearchIndex`, `SettingsSubpageNavigationState`, `SettingsScrollableContent`, `DSGroup`, and existing tab views before creating new systems.
- Source layout uses colocated, uniquely named files. Do not create `Type+Concern.swift`.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Targeted settings tests | `./scripts/run-tests.sh --suite dev --file SettingsSectionTests --file SettingsSearchIndexTests --file SettingsSubpageNavigationStateTests` | exit 0 |
| Preview coverage | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Full lane gate before push | `make build-test && make lint` | exit 0, or documented unrelated baseline failures |

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift`
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/NavigationService.swift` only if needed for typed routing helpers
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSectionTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift`

**Out of scope**:

- Moving tab content between pages. That is plans 011-013.
- Renaming stored user defaults or changing app behavior.
- Window-management refactors.

## Git workflow

- Branch: `advisor/010-consolidated-settings-routing-foundation`
- Commit style: `refactor(settings): add consolidated settings route foundation`
- Do not push/open a PR unless instructed.

## Steps

### Step 1: Add consolidated visible section cases

In `SettingsSection.swift`, add visible cases for:

- `activity`
- `intelligence`
- `system`

Keep the existing 12 cases for compatibility. Add helpers:

- `public var isLegacyRedirect: Bool`
- `public var visibleSection: SettingsSection`
- `public static func resolvedVisibleSection(for rawValue: String) -> SettingsSection?`

Target mapping:

- `.metrics` and `.transcriptions` -> `.activity`
- `.models`, `.enhancements`, and `.vocabulary` -> `.intelligence`
- `.audio`, `.permissions`, and `.general` -> `.system`
- `.dictation`, `.meetings`, `.assistant`, `.integrations` -> themselves

Do not add the new cases to the sidebar arrays yet unless the detail view compiles for them in this same step.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` -> existing tests fail until Step 2 updates expectations.

### Step 2: Update section tests around the new contract

Update `SettingsSectionTests.swift` to assert:

- `SettingsSection.visibleSections` or the updated sidebar arrays return exactly `[.activity, .dictation, .meetings, .assistant, .integrations, .intelligence, .system]` once this foundation is complete.
- each old raw value resolves to the intended visible section.
- the old raw values still parse as `SettingsSection` so existing deep links do not crash.

Prefer a named property such as `visibleSections` over overloading `primarySections` and `settingsSections` with unclear meaning. `SettingsSidebarView` can still present two visual groups later, but the model should name the product concept.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` -> exit 0.

### Step 3: Route incoming section requests through the resolver

In `SettingsPage.swift`, replace direct `SettingsSection(rawValue:)` use in both request handlers with `SettingsSection.resolvedVisibleSection(for:)`.

Keep `selectSection(_:)` as the single place that updates selected state. Do not scatter legacy redirect logic across search, menu, and warning call sites.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests --file SettingsSearchIndexTests` -> exit 0.

### Step 4: Add placeholder detail routing for new visible sections

Update `detailView` so the new visible cases compile even before plans 011-013 move content:

- `.activity` may initially show `MetricsDashboardSettingsTab`.
- `.intelligence` may initially show `ModelsSettingsTab`.
- `.system` may initially show `GeneralSettingsTab`.

Leave old cases in the switch and route them to their current views. Plans 011-013 will remove old cases from the visible sidebar and add proper consolidated container pages.

**Verify**: `make build-agent` -> exit 0.

### Step 5: Update search section mapping to visible destinations

Update `SettingsSearchIndex.section(forLocalizationKey:)` so search results return the visible destination for consolidated areas:

- metrics/history/transcriptions keys -> `.activity`
- models/text context/post-processing/dictionary keys -> `.intelligence`
- audio/permissions/general/storage keys -> `.system`

Keep exact tests for representative keys. Search result `detail` should show the visible section title.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` -> exit 0.

### Step 6: Run the thermo-nuclear review and fix its blockers

Invoke the `thermo-nuclear-code-quality-review` skill. Use this exact review scope:

```text
Perform a deep code quality audit of the current branch changes for consolidated settings routing. Focus on whether this introduced spaghetti conditionals, unnecessary wrappers, legacy raw-value leaks, or a route model that does not earn its keep. Require direct, maintainable code and reuse of existing settings/search/navigation helpers.
```

Fix every structural blocker it reports before marking the plan done. If the review says the route model is too generic or spreads redirects across multiple files, collapse the design back into one obvious helper on `SettingsSection`.

**Verify**: rerun all commands from "Commands you will need".

## Test plan

- Update `SettingsSectionTests` for visible-section order and legacy redirects.
- Update `SettingsSearchIndexTests` for representative consolidated routes.
- No screenshot QA required in this foundation plan.

## Done criteria

- [ ] Sidebar-visible section contract exists and is tested.
- [ ] Old section raw values resolve to consolidated visible destinations.
- [ ] Search maps representative old keys to the new visible destinations.
- [ ] `make build-agent` exits 0.
- [ ] Thermo-nuclear review blockers are fixed or documented as rejected with rationale.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- A deep link must change persistent user data to work.
- The route foundation requires changing unrelated app window behavior.
- The implementation adds a generic navigation framework larger than the settings code it replaces.

## Maintenance notes

Reviewers should reject any follow-up plan that adds more one-off `if selectedSection == .oldCase` logic instead of using the route contract from this plan.
