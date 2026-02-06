# Dependencies Audit (Issue #37)

Date: 2026-02-03  
Branch: `codex/issue-37-deps-audit`  
Scope: **all dependencies** (runtime, tests, local tooling, CI/CD, scripts).

## Sources reviewed

- SwiftPM:
  - `Packages/MeetingAssistantCore/Package.swift` (declared direct dependencies)
  - `Packages/MeetingAssistantCore/Package.resolved` (top-level pins)
  - `Packages/MeetingAssistantCore/.build/workspace-state.json` + `Packages/MeetingAssistantCore/.build/checkouts/` (local workspace checkouts)
- Project / build:
  - `MeetingAssistant.xcodeproj/project.pbxproj`
  - `Makefile`
  - `scripts/*`
- CI/CD:
  - `.github/workflows/ci.yml`
  - `.github/workflows/release.yml`
  - `.github/workflows/generate-docs.yml`

> Note: `Package.resolved` does **not** list transitive dependencies directly. For transitives/checkouts, `workspace-state.json` can help, but it may become stale (e.g., old checkouts left in `.build`). The source of truth for what the project declares is `Package.swift`.

---

## Dependency list (by category)

### In use

#### SwiftPM (direct)

- **FluidAudio** (`0.10.0`) — runtime (core feature)
  - Evidence: `@preconcurrency import FluidAudio` in `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/FluidAudioProvider.swift` and `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/FluidAIModelManager.swift`.
- **KeyboardShortcuts** (`2.4.0`) — runtime (global shortcuts)
  - Evidence: `import KeyboardShortcuts` in `App/GlobalShortcutController.swift`, `App/AssistantShortcutController.swift` and Core settings.
- **swift-atomics** (`1.3.0`) — runtime (audio pipeline state / concurrency)
  - Evidence: `import Atomics` + `ManagedAtomic` in `SystemAudioRecorder.swift`, `AudioRecordingWorker.swift`, `AudioRecorder.swift`.
- **swift-syntax** (`602.0.0`) — build-time (Swift macros for mocks)
  - Evidence: macro target `MeetingAssistantCoreMockingMacros` in `Packages/MeetingAssistantCore/Package.swift`.

#### SwiftPM (workspace checkouts / transitives)

> The list below contains packages seen in `.build` as checkouts. They may be pulled transitively by SwiftPM **or** they may be leftovers from previous resolves (stale).

- AEXML (`4.7.0`)
- FileKit (`6.1.0`)
- PathKit (`1.0.1`)
- Rainbow (`4.2.1`)
- Spectre (`0.10.1`)
- Stencil (`0.15.1`)
- TOMLKit (`0.6.0`)
- XcodeProj (`9.7.2`)
- swift-argument-parser (`1.7.0`)

#### Local tooling / scripts

- **SwiftFormat** — formatting
  - Evidence: `Makefile` uses `swiftformat` in the `format` target.
  - Evidence: `scripts/lint.sh`, `scripts/lint-fix.sh`, and `scripts/hooks/pre-commit`.
- **SwiftLint** — lint
  - Evidence: `make lint` and `scripts/lint.sh`, `scripts/lint-fix.sh`, `scripts/code-health-check.sh`, `scripts/hooks/pre-commit`.
- **PR heuristics (script)** — lightweight checks (warnings)
  - Evidence: `scripts/pr-checks.sh`.
- Apple tooling (environment)
  - `xcodebuild`, `codesign`, `hdiutil` (used by Makefile/scripts/workflows).

#### CI/CD (GitHub Actions)

- CI workflow (`.github/workflows/ci.yml`)
  - Lint: installs `swiftlint`/`swiftformat` and runs `STRICT_LINT=1 make lint`.
  - Tests: runs `make ci-test`.
- Release workflow (`.github/workflows/release.yml`)
  - Builds release + creates DMG + uploads artifact + drafts GitHub release.

---

### Not in use (strong candidates)

- **Cuckoo** (test-only) — removed in the audited branch.
  - Note: stale checkouts may still appear in `Packages/MeetingAssistantCore/.build/` until `swift package reset` (or deleting `.build`).

---

### Under discussion (keep until there is a clear replacement)

- **swift-syntax**
  - Current usage: Swift macros (mocks).
  - Trade-off: removes external mock tooling, but adds a large build-time dependency.
  - Suggested direction: keep while macros are the standard, revisit if mocking becomes test-only or moves to a dedicated target.

- **swift-atomics**
  - Current usage: small flags/counters in audio hot paths.
  - Suggested direction: keep; revisit only with a dedicated stress/TSan window.

## Recommendations and impact (as implemented in the audit branch)

### Phase 1 — immediate hygiene

1) **Release workflow cleanup** (remove lint/format installation)
- Result: faster and less variable release jobs.

2) **Decide on XcodeGen** (treat `.xcodeproj` as the source of truth)
- Result: less ambiguity; the trade-off is manual `.xcodeproj` drift (mitigated by review/CI).

### Phase 2 — reduce CI/setup cost

3) **Retire Danger-Swift**
- Replacement: strict lint gate + `scripts/pr-checks.sh` warnings.
- Result: less CI setup and fewer moving parts.

### Phase 3 — longer-term structural work

4) **Testing strategy (replace Cuckoo)**
- Result: mocks via Swift macros.
- Trade-off: build-time dependency on `swift-syntax`.

5) **Concurrency maintenance**
- Result: keep `swift-atomics` for safety in audio hot paths; revisit when stress testing is available.
