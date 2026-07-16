# Plan 048: Improve Launch at Login failure diagnostics

> **Executor instructions**: Preserve rollback behavior and platform semantics. This is a medium-risk UI/state change with mandatory thermo review; correct all Critical/Medium findings.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/UI/ViewModels/GeneralSettingsViewModel.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/GeneralSettings* plans/README.md`

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MED
- **Depends on**: plans/041-modernize-swiftui-interactions-and-accessibility.md
- **Category**: bug
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issue**: #66

## Why this matters

When `SMAppService.mainApp.register()` or `unregister()` fails, the current ViewModel logs the error and rolls the toggle back, but the user receives no actionable explanation. Development/ad-hoc builds can legitimately fail for signing or registration reasons, so the UI must distinguish rollback from success without exposing technical noise.

## Current state

- `GeneralSettingsViewModel.swift:379-398` performs the registration and only logs the caught error before reverting state on the main queue.
- `GeneralSettingsTab.swift` binds the launch-at-login toggle directly to the ViewModel.
- Existing settings tests cover appearance/audio and should be extended with a mock launch-at-login service rather than invoking `SMAppService` in tests.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'GeneralSettings.*Tests|AppSettingsStoreCapabilityTests'` | exit 0 |
| Preview/build | `make preview-check && make build-agent` | both exit 0 |
| Full gates | `make lint && make build-test` | exit 0, baseline classified |

## Scope

**In scope**:

- Launch-at-login state/error handling in `GeneralSettingsViewModel`.
- General settings UI copy/state presentation and localization keys in both supported languages.
- Focused tests with an injectable platform service seam if needed.
- `plans/README.md`

**Out of scope**:

- Changing signing, entitlements, login-item packaging, or SMAppService registration policy.
- Showing raw OS error strings or sensitive paths.

## Steps

### Step 1: Add a testable registration seam

Reuse or introduce the smallest protocol/closure seam for register/unregister/status. Keep the production adapter thin and AppKit/platform-owned.

**Verify**: tests can simulate success and failure without calling the real service.

### Step 2: Expose actionable localized failure state

On failure, restore the previous setting, expose a localized error state, and provide a clear next action such as checking app permissions/signing or retrying. Clear the message after dismissal or a new successful operation.

**Verify**: tests cover register failure, unregister failure, rollback, success, and repeated retry.

### Step 3: Review accessibility and behavior

Run thermo review with accessibility guidance. Check VoiceOver announcement, focus, toggle state, localization, and no raw error leakage. Correct all Critical/Medium findings.

**Verify**: `make preview-check` and focused tests pass.

### Step 4: Run full gates and update issue #66

Run `make lint` and `make build-test`, then record the final behavior in the issue.

**Verify**: commands and review result are recorded; ledger row updated.

## Done criteria

- [x] Launch-at-login failures are visible and actionable.
- [x] Toggle state rolls back consistently on failure.
- [x] Tests do not require real signing or SMAppService registration.
- [x] Localization, preview, build, lint, and full gates pass.
- [x] Thermo review has no unresolved Critical/Medium findings.
- [x] `plans/README.md` status row updated.

## Validation evidence — 2026-07-12

- `swift test --package-path Packages/MeetingAssistantCore --filter 'GeneralSettings.*Tests|AppSettingsStoreCapabilityTests'`: 13 passed.
- `swift test --package-path Packages/MeetingAssistantCore --filter 'LocalizationKeyIntegrityTests|GeneralSettings.*Tests|AppSettingsStoreCapabilityTests'`: 15 passed.
- `make preview-check`: passed.
- `make build-agent`: passed.
- `make lint`: non-blocking repository baseline; 362/504 files require formatting and 288 warnings. The touched files have no new blocking violation.
- `make build-test`: build passed; 993 executed, 17 skipped, 977 passed, 16 known `MetricsDashboardViewModelTests` failures. CoreSimulator device-support and service-availability messages are environmental.
- Thermo/accessibility review: no unresolved Critical/Medium findings. The alert is localized in EN/PT, exposes only stable failure categories, preserves VoiceOver-readable title/message/actions, and provides retry plus rollback.

## STOP conditions

- The platform does not expose a stable error category that can support actionable copy.
- The fix requires changing entitlements or release packaging.
- Tests would need a real login item or signed application.

## Maintenance notes

Keep platform errors in diagnostics, but map them to stable user-facing categories. Do not make the ViewModel depend directly on `SMAppService` in future tests.
