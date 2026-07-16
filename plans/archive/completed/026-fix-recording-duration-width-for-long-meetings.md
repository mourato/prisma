# Plan 026: Fix recording duration width for long meetings

> **Executor instructions**: Follow this plan step by step. Run the drift check first. Stop if the cited code has moved materially. This is a UI bugfix in the recording indicator; keep the change narrowly scoped. After implementation, run the mandatory code review step with the thermo-nuclear structural pass and fix every critical/medium finding before marking DONE.
>
> **Drift check (run first)**:
> `git diff --stat 2db76a6b..HEAD -- Packages/MeetingAssistantCore/Sources/UI/Presentation/FloatingRecordingIndicatorController.swift Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/FloatingRecordingIndicatorView.swift Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorSupport.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/FloatingRecordingIndicatorWidthTests.swift`
>
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against live code. On a meaningful mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: 025 for merge-order stability only
- **Category**: bug / ui
- **Planned at**: commit `2db76a6b`, 2026-07-08

## Why this matters

The meeting recording duration label changes from `MM:SS` to `H:MM:SS` once a meeting reaches one hour, but the pill still reserves a fixed 48-56 px width. Long meetings can therefore clip or visually crowd the duration control. Fix the sizing in the shared recording-indicator utilities so the pill and its NSPanel budget enough width for hour-long durations without truncation or ellipses.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorSupport.swift:206-214` formats durations with hours after `3_600` seconds.
- `FloatingRecordingIndicatorSupport.swift:216-225` returns fixed timer widths: 56 px for classic/super and 48 px for mini.
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/FloatingRecordingIndicatorView.swift:371-409` applies `.frame(width: timerReservedWidth(...))`, `.lineLimit(1)`, and `.fixedSize(horizontal: true, vertical: false)` to the timer text.
- `FloatingRecordingIndicatorSupport.swift:360-363` uses `timerReservedWidth` in `mainPillWidth`.
- `FloatingRecordingIndicatorSupport.swift:497-499` uses `timerReservedWidth` for the super footer chip.
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/FloatingRecordingIndicatorWidthTests.swift:7-39` already tests that the timer width contribution matches the layout budget.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter FloatingRecordingIndicatorWidthTests` | all tests pass |
| Preview coverage | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Scoped gate | `make scope-check` | exit 0, or documented unrelated baseline failures |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/FloatingRecordingIndicatorView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorSupport.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Presentation/FloatingRecordingIndicatorController.swift`, only if panel sizing needs a new parameter after plan 025
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/FloatingRecordingIndicatorWidthTests.swift`

**Out of scope**:

- Changing duration formatting semantics
- Recording lifecycle, auto-start behavior, stop/cancel behavior
- Meeting notes panel
- Processing status sizing, unless an existing helper can be reused without broadening scope
- Replacing the floating indicator layout system

## Git workflow

- Branch: `advisor/026-recording-duration-width`
- Commit style: `fix(ui): prevent meeting duration clipping in recording pill`
- Do not push or open a PR unless instructed.

## Steps

### Step 1: Replace fixed timer width with measured duration-safe width

Update `FloatingRecordingIndicatorViewUtilities.timerReservedWidth(for:)` so it reserves enough width for hour-long meeting durations. Prefer a measured helper using the same font family/size/weight as `meetingTimerView`, for example:

- `timerFont(for size:) -> NSFont`
- `timerReservedWidth(for size:) -> CGFloat`
- a private sample text such as `00:00:00` or a measured max of `00:00` and `00:00:00`

Keep the helper deterministic. Do not make panel width depend on a per-second live value unless that is already needed after plan 025; a stable hour-safe width is better than a panel that resizes every second.

**Verify**:
`swift test --package-path Packages/MeetingAssistantCore --filter FloatingRecordingIndicatorWidthTests` -> existing tests compile after updating expected width calculations.

### Step 2: Make the timer text use the same width contract as the panel

Update `meetingTimerView` so the `Text` frame uses the same helper as panel sizing and does not truncate at one hour. Keep:

- `.monospacedDigit()`
- `.lineLimit(1)`
- no ellipsis/truncation for normal hour-long durations
- no layout shifts on hover

If you introduce a font helper, use it both for measurement and the SwiftUI text.

**Verify**:
`swift test --package-path Packages/MeetingAssistantCore --filter FloatingRecordingIndicatorWidthTests` -> tests pass.

### Step 3: Update panel/footer width tests

Extend `FloatingRecordingIndicatorWidthTests` with explicit coverage:

- `formatRecordingDuration` returns an hour-bearing string for a duration over 3,600 seconds.
- `timerReservedWidth(for: .classic)` is wide enough for the hour-bearing sample.
- `mainPillWidth` includes the new timer width contribution.
- `superFooterLeadingWidth` or `superCardWidth` has enough budget when the meeting timer is shown.

Keep the test deterministic; do not depend on the current date except through fixed `Date(timeIntervalSinceReferenceDate:)` values.

**Verify**:
`swift test --package-path Packages/MeetingAssistantCore --filter FloatingRecordingIndicatorWidthTests` -> all tests pass.

### Step 4: Run the required thermo-nuclear code review

Run a semaforo review of the diff and include the thermo-nuclear structural pass. This review must specifically inspect:

- no ad-hoc hardcoded width duplicated between the view, controller, and tests
- no timer-specific special cases scattered into unrelated indicator paths
- no dynamic panel-resize loop caused by per-second timer changes
- no processing-status or assistant/dictation layout regression
- no new local UI primitive for a simple measurement fix

Fix every critical and medium finding before continuing. Minor findings may be deferred only if documented.

**Verify**:
Reviewer notes list the semaforo outcome and confirm the thermo pass found no blocking structural regression.

## Test plan

- Add deterministic unit coverage in `FloatingRecordingIndicatorWidthTests`.
- Run preview coverage because the affected surface is SwiftUI.
- Run `make build-agent` for compile confidence.
- Run `make scope-check` and `make lint` before handoff.

## Done criteria

- [ ] Meeting duration text for one hour or more is not clipped or ellipsized in classic, mini, or super styles.
- [ ] Timer width is owned by one shared helper and reused by layout calculations.
- [ ] Existing processing-status width behavior remains unchanged.
- [ ] `FloatingRecordingIndicatorWidthTests`, `make preview-check`, `make build-agent`, `make scope-check`, and `make lint` were run, with only documented unrelated baseline failures if any.
- [ ] Thermo-nuclear code review was completed and all critical/medium findings were fixed.
- [ ] `plans/README.md` row for plan 026 is updated.

## STOP conditions

Stop and report if:

- the fix appears to require changing recording duration formatting
- the panel must resize every second to avoid clipping
- the implementation needs changes outside the recording indicator files listed in Scope, except for merge-conflict resolution after plan 025
- tests reveal the existing indicator panel cannot accommodate the corrected timer without broader layout redesign
- any verification command fails twice after a reasonable fix attempt

## Maintenance notes

- Future indicator width changes should update `FloatingRecordingIndicatorViewUtilities` and `FloatingRecordingIndicatorWidthTests` together.
- Do not reintroduce fixed timer constants unless they are derived from measured text plus padding.
- If plan 025 lands first, re-run the confirmation-pill width tests after this fix to ensure both sizing paths still share the same panel budget model.
