# Plan 041: Modernize SwiftUI interactions and accessibility semantics

> **Executor instructions**: Implement only the cited UI corrections. Every code review finding marked Critical or Medium must be corrected before the final gates.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/transcription/TranscriptionAudioPlayerView.swift Packages/MeetingAssistantCore/Sources/UI/pages/transcription/TranscriptionStatusPage.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardComponents.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardPages.swift Packages/MeetingAssistantCore/Sources/UI/components/onboarding plans/README.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/038-define-swiftui-swift6-platform-standards.md
- **Category**: bug
- **Planned at**: commit `80ed5788`, 2026-07-12

## Why this matters

Several current views use image-only buttons, `onTapGesture` for button semantics, deprecated styling modifiers, and C-style formatting. These are not merely style differences: they affect VoiceOver, keyboard interaction, localized output, and future SwiftUI maintenance.

## Current state

- `TranscriptionAudioPlayerView.swift:28-37` creates a play/pause button whose label is only an `Image`.
- `TranscriptionStatusPage.swift:54` attaches `onTapGesture` to a status row and adds a button trait only to the chevron image at line 205.
- `MetricsDashboardComponents.swift:406` attaches `onTapGesture` to a calendar row that contains other action buttons.
- `OnboardingPermissionsView.swift`, `OnboardingCompletionView.swift`, `OnboardingShortcutsView.swift`, `OnboardingMeetingRecordingView.swift`, and `OnboardingDownloadModelsView.swift` contain 23 `foregroundColor()` calls.
- `MetricsDashboardPages.swift:542` uses `cornerRadius()`.
- UI paths still use `String(format:)` for time and metric presentation.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| UI tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'TranscriptionSettingsViewModelTests|MetricsDashboardNavigationTests|OnboardingMeetingRecordingTests'` | exit 0 |
| Preview coverage | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Lint | `make lint` | exit 0 with no new warnings |
| Pattern scan | `rg -n 'foregroundColor\(|cornerRadius\(|onTapGesture' <in-scope paths>` | no cited legacy patterns remain |

## Scope

**In scope**:

- The three interaction files above and their focused tests/previews.
- Onboarding files containing `foregroundColor()`.
- `MetricsDashboardPages.swift` styling/formatting lines.
- UI-owned time/metric formatters only when the output is user-visible and behavior can be preserved.
- `plans/README.md`

**Out of scope**:

- Rewriting legitimate waveform/progress `GeometryReader` usage.
- Redesigning the settings taxonomy or AppKit panels.
- Replacing every Foundation formatter in storage, hashing, logging, or protocol code.
- Changing user-visible copy without localization updates in all supported languages.

## Steps

### Step 1: Replace ambiguous interactive surfaces

Make the audio play/pause control a labeled `Button`, retaining an icon-only visual style through `.labelStyle(.iconOnly)` where appropriate. Replace the transcription status row gesture with a real button or a clearly separated button surface. Remove the parent tap gesture from the calendar row when it conflicts with child actions; provide an explicit open-detail button with a localized label.

**Verify**: focused UI tests and `make preview-check` -> exit 0.

### Step 2: Apply modern SwiftUI APIs

Replace `foregroundColor` with `foregroundStyle`, `cornerRadius` with `clipShape(.rect(cornerRadius:))`, and user-visible C-style numeric formatting with `FormatStyle`/localized interpolation where the output contract permits. Preserve exact timer widths only where layout tests require deterministic rendering.

**Verify**: `rg -n 'foregroundColor\(|cornerRadius\(' <in-scope paths>` -> no matches.

### Step 3: Validate accessibility and review

Check VoiceOver labels, keyboard activation, disabled states, Reduce Motion behavior, and non-color status cues in each changed surface. Run thermo review with `accessibility-audit` guidance; correct all Critical/Medium findings.

**Verify**: `make lint && make build-agent && make preview-check` -> exit 0; review has no unresolved Critical/Medium findings.

## Test plan

- Add/adjust tests for status expansion and calendar detail activation if the current test surface permits it.
- Keep existing onboarding readiness tests.
- Verify previews for enabled/disabled, loading/error, and expanded/collapsed states.

## Done criteria

- [ ] All cited image-only controls expose a localized accessibility label.
- [ ] Cited parent gestures no longer simulate buttons or conflict with nested buttons.
- [ ] Cited `foregroundColor()` and `cornerRadius()` calls are replaced.
- [ ] User-visible formatting uses locale-aware APIs where changed.
- [ ] `make lint`, `make build-agent`, `make preview-check`, and focused tests pass.
- [ ] Thermo/accessibility review has no unresolved Critical/Medium findings.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Replacing a gesture changes a required double-click, pointer-location, or drag interaction.
- A formatting replacement changes localized output or fixed-width timer behavior without a testable alternative.
- A proposed accessibility fix requires a product copy decision; stop and record the missing localization decision.

## Maintenance notes

New controls should use semantic `Button`/`Toggle`/`Menu` APIs first. A visual icon-only control must still have a textual accessibility label. Keep `accessibility-audit` as the specialist review owner for future AppKit/SwiftUI interaction changes.
