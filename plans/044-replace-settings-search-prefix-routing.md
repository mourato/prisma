# Plan 044: Replace brittle SettingsSearchIndex prefix routing

> **Executor instructions**: Preserve all current destinations and legacy aliases. This is a medium-risk routing change with mandatory code review; correct all Critical/Medium findings.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndex.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift plans/README.md`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/038-define-swiftui-swift6-platform-standards.md
- **Category**: tech-debt
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #124

## Why this matters

`SettingsSearchIndex.destination(forLocalizationKey:)` combines special-case checks with a growing ordered prefix array. Current entries include overlapping prefixes such as `settings.enhancements.selector.meeting.`, `settings.enhancements.`, and multiple legacy aliases. A missing or misordered entry silently routes search results to the wrong Settings destination.

## Current state

- `SettingsSearchIndex.swift:46-87` contains special-case routing.
- `SettingsSearchIndex.swift:126+` contains the ordered `prefixMappings` array.
- `SettingsSearchIndex.swift` also contains exact mappings and legacy key aliases.
- `SettingsSearchIndexTests.swift` is the existing routing contract and must remain the source of truth for compatibility.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Routing tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSearchIndexTests|SettingsSectionTests'` | exit 0 |
| Preview/build | `make preview-check && make build-agent` | both exit 0 |
| Full gates | `make lint && make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- `SettingsSearchIndex.swift`
- `SettingsSearchIndexKeys.swift` if the canonical manifest belongs there
- `SettingsSection.swift` only for an existing route contract
- `SettingsSearchIndexTests.swift` and focused localization/search fixtures
- `plans/README.md`

**Out of scope**:

- Changing visible Settings taxonomy.
- Removing legacy aliases without a migration/compatibility test.
- Rewriting localization strings or search ranking unrelated to destination routing.
- Adding a second navigation system.

## Steps

### Step 1: Freeze current routing behavior

Add table-driven tests for every current prefix family, overlapping exception, exact mapping, legacy key, and unknown key. The tests must assert both section and destination/subroute.

**Verify**: routing tests pass before implementation.

### Step 2: Introduce a typed routing manifest

Represent canonical key families and explicit exceptions in one named manifest. Resolve the canonical structured prefix first, then apply explicit overrides for legacy/exceptional keys. Keep matching deterministic and make precedence visible in code rather than dependent on incidental array order.

**Verify**: routing tests pass, including all frozen compatibility cases.

### Step 3: Add completeness protection

Add a test or validation helper that detects newly introduced searchable localization keys without a route, but allow an explicit `unrouted`/non-searchable classification where appropriate. Do not require every localization key to be a Settings search result.

**Verify**: the integrity test fails for an intentionally unclassified searchable fixture and passes when the fixture is explicitly classified.

### Step 4: Review and validate

Run thermo review focused on route precedence, backward compatibility, hidden default routes, and test completeness. Correct all Critical/Medium findings, then run full gates.

**Verify**: `make lint && make build-test` -> recorded result; no unresolved Critical/Medium findings.

## Done criteria

- [ ] Current search destinations and legacy aliases have table-driven coverage.
- [ ] Canonical routing no longer depends on an opaque growing ordered prefix list.
- [ ] Exceptions are explicit and tested.
- [ ] Unrouted searchable keys are detected by a test/validator.
- [ ] Focused tests, previews/build, lint, and full gate are recorded.
- [ ] Thermo review has no unresolved Critical/Medium findings.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- The current UI requires prefix order for a behavior not represented in the route model.
- A complete key inventory cannot distinguish searchable Settings strings from unrelated localized strings.
- The refactor requires changing visible section names or deep-link semantics.

## Maintenance notes

When adding a Settings page, update the route manifest, search index metadata, localization keys, and routing tests together. Do not reintroduce scattered `hasPrefix` checks in callers.
