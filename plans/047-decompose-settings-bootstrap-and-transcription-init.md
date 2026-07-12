# Plan 047: Decompose settings bootstrap and transcription initialization

> **Executor instructions**: This is a core-state refactor. Preserve persisted defaults, migration order, and public APIs. Run the mandatory thermo review and correct all Critical/Medium findings.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/AppSettings.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/Transcription.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppSettingsStore* Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Transcription* plans/README.md`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: plans/039-align-swift6-concurrency-baseline.md
- **Category**: tech-debt
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #112

## Why this matters

`AppSettings.swift` is 889 lines, its type body exceeds the configured serious threshold, and its initializer spans 130 lines. `Transcription.swift` also contains a 132-line function. These are central state/bootstrap paths where extraction can accidentally change default precedence or side-effect ordering.

## Current state

- `AppSettings.swift:11` defines the large `AppSettingsStore` type and `:746` contains the oversized initializer.
- The store is split into colocated extensions under `Infrastructure/Models/AppSettingsStore/`; reuse that structure.
- `Transcription.swift:12` contains the oversized initialization/processing entry point; existing recording tests cover its public behavior.
- Existing AppSettings tests cover defaults, decoding, provider/model selection, and recording settings.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Settings tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsStore.*Tests|GeneralSettings.*Tests|SettingsSearchIndexTests'` | exit 0 |
| Transcription tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'TranscriptionSettingsViewModelTests|TranscribeAudioUseCase.*Tests|RecordingManagerTests'` | exit 0 or known baseline classified |
| Build/lint | `make build-agent && make lint` | exit 0 |
| Full gate | `make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- `AppSettings.swift` and its existing colocated `AppSettingsStore` extensions.
- The specific oversized initialization function in `Transcription.swift` and focused support files.
- Existing AppSettings/transcription tests and new characterization tests.
- `plans/README.md`

**Out of scope**:

- Changing persisted keys, default values, migration versions, provider selection policy, or transcription business behavior.
- Migrating Observation; that is Plan 040.
- Reorganizing unrelated domain models or creating generic configuration frameworks.

## Steps

### Step 1: Freeze default and initialization behavior

Add or strengthen tests for default mode creation, legacy decoding, provider/model selection, storage paths, and initialization ordering. Capture side effects that must occur once.

**Verify**: focused settings and transcription tests pass before extraction.

### Step 2: Extract cohesive bootstrap helpers

Move default construction, persisted-value normalization, migration/backfill decisions, and dependency setup into existing owner-prefixed sibling files. Keep the public `AppSettingsStore` API stable and make ordering explicit. Extract transcription preparation/phase helpers only where they correspond to existing behavior boundaries.

**Verify**: tests and `make build-agent` pass.

### Step 3: Review and validate

Run thermo review focused on persisted-state compatibility, initialization order, actor isolation, duplicate defaults, and hidden side effects. Correct all Critical/Medium findings, then run lint and full tests.

**Verify**: no unresolved Critical/Medium findings; `make lint` and `make build-test` results recorded.

## Done criteria

- [ ] AppSettings bootstrap and the cited transcription function are below serious lint thresholds or have a documented residual rationale.
- [ ] Persisted keys/defaults/migrations are behaviorally unchanged.
- [ ] Focused tests pass and cover the extracted boundaries.
- [ ] Thermo review has no unresolved Critical/Medium findings.
- [ ] Full gates are attempted and recorded.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- A helper extraction changes persisted values, migration order, or default-mode identity.
- The refactor requires changing a public settings protocol or adding a new persistence layer.
- Existing tests cannot distinguish a behavior change from an old untested assumption.

## Maintenance notes

Keep AppSettings ownership in the existing `AppSettingsStore` directory. Reviewers should reject a generic “settings builder” abstraction that hides key/default ownership.
