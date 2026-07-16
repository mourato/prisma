# Plan 042: Decompose recording runtime hotspots without changing behavior

> **Executor instructions**: This is a High-risk recording refactor. Preserve lifecycle ordering and run the review step before claiming completion. Correct every Critical/Medium review finding.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingControl.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/Transcription.swift Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests plans/README.md`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/039-align-swift6-concurrency-baseline.md
- **Category**: tech-debt
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #114

## Why this matters

The recording path remains the highest-risk area for structural complexity. Current lint reports `RecordingControl.swift` at 775 lines with a 213-line function, `Transcription.swift` at 770 lines with a 132-line function, and `FloatingRecordingIndicatorView.swift` at 530 lines with a 452-line type body. The indicator file was already reduced by earlier work, so this plan must improve the remaining concentration rather than repeat the completed extraction.

## Current state

- `RecordingControl.swift:273` contains the 213-line recording start/stop orchestration function.
- `Transcription.swift:12` contains a 132-line function and `:612` has cyclomatic complexity 17.
- `FloatingRecordingIndicatorView.swift:12` remains a 452-line type despite being under the file-size threshold.
- Existing phase-based Assistant files and `AssistantRecordingOrchestratorTests` demonstrate the preferred decomposition pattern.
- Existing recording tests include `RecordingManagerTests`, `RecordingViewModelTests`, `AssistantRecordingOrchestratorTests`, and indicator render/layout tests.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Recording tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'RecordingManagerTests|RecordingViewModelTests|AssistantRecordingOrchestratorTests'` | exit 0 |
| Indicator tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'FloatingRecordingIndicatorWidthTests|RecordingIndicatorRenderStateTests|RecordingIndicatorOverlayLayoutTests'` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Full gates | `make lint && make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- `RecordingControl.swift`
- `Transcription.swift`
- `FloatingRecordingIndicatorView.swift` and colocated indicator siblings only when extraction is needed
- Existing focused recording/indicator tests and new pure helper tests
- `plans/README.md`

**Out of scope**:

- New recording behavior, state-machine changes, audio algorithm changes, or UI redesign.
- Moving ownership into `MeetingDetector`.
- Reopening completed plans 033–037 except where a pure extraction is required.
- `AppSettings.swift` and notes-editor files; they are separate hotspots.

## Steps

### Step 1: Characterize lifecycle boundaries

Map the current start, validation, stop, transcription, post-processing, cleanup, and error paths. Add missing tests for sequencing and failure cleanup before extraction. Use the existing phase/orchestrator pattern rather than generic service layers.

**Verify**: focused recording and indicator tests -> all pass before structural changes.

### Step 2: Extract cohesive runtime helpers

Split the large functions by real phases: preconditions/context, recorder startup, incremental session setup, stop/finalization, and cleanup/error recovery. Keep side-effect ordering explicit and preserve the public `RecordingManager` API. Extract indicator render subviews only for cohesive visual responsibilities; keep sizing and render-state contracts stable.

**Verify**: `make build-agent` and focused tests -> exit 0.

### Step 3: Run thermo review and correct findings

Review the full diff for state ownership, impossible transitions, cancellation, duplicate cleanup, hidden behavior changes, and abstraction value. Correct all Critical/Medium findings before full validation.

**Verify**: review report has no unresolved Critical/Medium findings.

### Step 4: Run full gates and record residual lint

Run `make lint` and `make build-test`. Any remaining warning must be either fixed in scope or explicitly recorded as a follow-up with its exact file/line.

**Verify**: both commands have recorded results and `plans/README.md` is updated.

## Done criteria

- [ ] Recording start/stop/transcription orchestration is split by concrete lifecycle phase.
- [ ] No public recording API or behavior changes without a dedicated requirement.
- [ ] Indicator type complexity is reduced or a precise residual rationale is recorded.
- [ ] Focused recording and indicator tests pass.
- [ ] Thermo review has no unresolved Critical/Medium findings.
- [ ] `make build-agent`, `make lint`, and `make build-test` results are recorded.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Extraction changes which component owns automatic recording confirmation or detector state.
- A helper needs to share mutable state across actors without an explicit ownership model.
- More than eight files outside the listed recording families are required.
- A test fails because behavior was previously implicit and no safe characterization exists.

## Maintenance notes

Keep new files colocated by owning type and avoid `Type+Concern.swift` filenames. Reviewers should reject helpers that merely move branches without reducing responsibilities.
