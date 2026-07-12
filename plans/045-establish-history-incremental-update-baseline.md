# Plan 045: Establish the history performance baseline before FRC or FTS

> **Executor instructions**: This plan is a measurement and decision slice. Do not introduce `NSFetchedResultsController` or FTS unless the measured baseline proves the need and the STOP conditions are satisfied. Code changes require thermo review.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/Data Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests scripts plans/README.md`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-persisted-history-query-limits.md
- **Category**: perf
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issues**: #97, #98; #53's query slice is already complete and should be closed.

## Why this matters

The original storage issue proposed batching, FRC, and text indexing together. The current code already has Core Data query predicates, batch size, and `loadMetadata(matching:)`, but updates still use notification-triggered reloads and substring search remains unindexed. Before adopting heavier architecture, Prisma needs reproducible measurements for query latency, reload cost, dataset size, and update frequency.

## Current state

- `RetentionCleanup.swift:126+` performs metadata queries with `fetchBatchSize = 100` but no general limit/sort contract yet.
- `TranscriptionSettingsViewModel` reloads on `meetingAssistantTranscriptionSaved` and filter/search changes.
- `CoreDataTranscriptionStorageRepository.swift` and `RetentionCleanup.swift` contain query paths and `CONTAINS[cd]` predicates.
- Existing `plans/001-persisted-history-query-limits.md` is the prerequisite bounded-query slice.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Persistence tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'CoreDataRepositoryTests|TranscriptionSettingsViewModelTests'` | exit 0 |
| Performance suite | `make test-perf` | exit 0 or baseline recorded |
| Build | `make build-agent` | exit 0 |
| Full gates | `make lint && make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- Existing history query/storage contracts and view-model reload path.
- Deterministic benchmark fixtures for small, medium, and large local datasets.
- Measurements for query latency, mapping, filtering, reload count, and active-filter correctness.
- A decision report under `.agents/reports/` only if the existing supported report path is used; otherwise record results in the plan/issue update.
- `plans/README.md`

**Out of scope**:

- FRC migration.
- Core Data schema/index migration.
- Full-text search implementation.
- Product changes to history navigation.

## Steps

### Step 1: Complete or verify bounded query behavior

Run the existing Plan 001 drift check. If it is not complete, stop and execute that plan first. Confirm that query limits do not hide required history behavior.

**Verify**: Plan 001 focused tests pass and the current query contract is documented.

### Step 2: Add deterministic measurement fixtures

Create in-memory Core Data fixtures with representative transcription metadata, active filters, search text, insert/update/delete events, and realistic row counts. Measure query and reload work without using live provider data or personal recordings.

**Verify**: performance tests produce stable measurements across repeated runs and assert correctness for every active filter.

### Step 3: Decide the next architecture slice

Use explicit thresholds recorded in the test/report to choose one of: retain notification reloads, introduce a diff-based view-model update, prototype FRC, or investigate FTS. Do not select FRC/FTS solely because an issue exists.

**Verify**: issue updates for #97 and #98 state the measured baseline and chosen next step.

### Step 4: Review and validate

Run thermo review focused on Core Data context ownership, stale selection, active filters, memory, and test determinism. Correct all Critical/Medium findings, then run the full gates.

**Verify**: no unresolved Critical/Medium findings; required commands have recorded results.

## Done criteria

- [ ] Bounded query behavior is verified before measurement.
- [ ] Deterministic fixtures cover query, mapping, and reload costs at multiple dataset sizes.
- [ ] A measured decision exists for #97 and #98.
- [ ] No FRC/FTS code was added without measured justification.
- [ ] Focused tests, `make test-perf`, build, lint, and full gate are recorded.
- [ ] Thermo review has no unresolved Critical/Medium findings.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Measurements depend on live data, provider credentials, or an unavailable large dataset.
- Plan 001's bounded query contract is not complete.
- FRC/FTS would require a schema or UI architecture decision not captured in this plan.

## Maintenance notes

Keep #97 and #98 separate until measurement proves they should share an implementation. The current Core Data query contract is reusable; do not bypass it with a second storage path.
