# Plan 039: Align the project with Swift 6.2 concurrency checks

> **Executor instructions**: Follow this plan in order. This is a High-risk build/concurrency migration. Every code review finding marked Critical or Medium must be corrected before the final gates.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- .swift-version Packages/MeetingAssistantCore/Package.swift MeetingAssistant.xcodeproj/project.pbxproj App Packages/MeetingAssistantCore/Sources Packages/MeetingAssistantCore/Tests plans/README.md`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/038-define-swiftui-swift6-platform-standards.md
- **Category**: migration
- **Planned at**: commit `80ed5788`, 2026-07-12
- **Related issues**: none

## Why this matters

The local toolchain reports Xcode 26.6 and Swift 6.3.3, but the app and XPC targets still declare `SWIFT_VERSION = 5.0`; the package manifest uses Swift tools 6.0 and `.swift-version` contains 6.0. Without a single language mode and strict concurrency policy, the compiler cannot reliably expose actor-isolation and Sendable problems in recording, persistence, and UI state.

## Current state

- `MeetingAssistant.xcodeproj/project.pbxproj:391,401,479,493,504,518,529,539` sets macOS 15 and Swift 5.0 for app/XPC configurations.
- `Packages/MeetingAssistantCore/Package.swift:1` uses `// swift-tools-version: 6.0`.
- `.swift-version:1` contains `6.0`.
- The codebase has direct `DispatchQueue.main.async` usage, 39 `Task.sleep(nanoseconds:)` calls, and multiple `Task.detached` paths.
- UI services already use explicit `@MainActor` in places such as `AssistantVoiceCommandService` and `FloatingRecordingIndicatorController`; reuse those boundaries.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Concurrency-focused tests | `make test-sensitive` | exit 0, or classify existing baseline failures |
| Build | `make build-agent` | exit 0 |
| Architecture | `make arch-check` | exit 0 |
| Full gates | `make lint && make build-test` | exit 0, with unrelated baseline explicitly recorded |
| Concurrency search | `rg -n "DispatchQueue|Task\.detached|Task\.sleep\(nanoseconds:|@MainActor|Sendable" App Packages/MeetingAssistantCore/Sources Packages/MeetingAssistantCore/Tests --glob '*.swift'` | every retained legacy use has a documented boundary or rationale |

## Scope

**In scope**:

- `.swift-version`
- `Packages/MeetingAssistantCore/Package.swift`
- `MeetingAssistant.xcodeproj/project.pbxproj`
- concurrency settings required by the Xcode/package targets
- source files required to resolve diagnostics exposed by the new mode
- focused concurrency/audio/persistence tests
- `plans/README.md`

**Out of scope**:

- Behavioral redesign of recording, storage, or model residency.
- Blanket replacement of every Combine `receive(on:)` call without checking its integration boundary.
- `Task.detached` removal when an actor or explicit nonisolated boundary is measurably required.
- Swift 6.2-only APIs that would force the macOS 15 deployment target upward.

## Steps

### Step 1: Establish the compiler mode without behavior changes

Set the canonical Swift version to Swift 6.2 or the repository's agreed newer language mode. Update the package tools version only as far as supported by the installed toolchain. Configure strict concurrency checking and default actor isolation deliberately; do not enable a flag without recording why it applies to the app, package, and XPC targets.

**Verify**: `make build-agent` -> the project compiles and diagnostics are captured in a reproducible log.

### Step 2: Classify and remediate concurrency diagnostics

For each diagnostic, classify it as UI state (`@MainActor`), shared mutable service state (actor/lock), immutable value (`Sendable`), or platform callback (`@preconcurrency` only at the import boundary). Replace `Task.sleep(nanoseconds:)` with `Task.sleep(for:)` where semantics are unchanged. Keep audio callbacks allocation-minimal and off the main actor.

**Verify**: `make test-sensitive` -> focused audio/concurrency/persistence tests pass.

### Step 3: Review the migration

Run `thermo-nuclear-code-quality-review` against the complete diff. The review must specifically inspect actor boundaries, cancellation, `Sendable` escapes, `Task.detached`, `@preconcurrency`, and any changed public package API. Correct all Critical and Medium findings before continuing.

**Verify**: review report contains no unresolved Critical/Medium findings.

### Step 4: Run full gates and update the ledger

Run `make lint`, `make build-test`, and `make arch-check`. Record known unrelated failures separately; do not mark the plan complete if the new language mode introduces unclassified failures.

**Verify**: all required commands have a recorded result and `plans/README.md` is updated.

## Test plan

- Preserve the existing `ConcurrencyTests`, `AudioRecorderTests`, `AudioRecordingWorkerTests`, `CoreDataRepositoryTests`, and `StorageServiceSecurityTests` coverage.
- Add regression tests only where an actor boundary or cancellation behavior changes.
- Verify at least one cancellation path for every new long-running task.

## Done criteria

- [ ] App, XPC, package, and `.swift-version` agree on the chosen Swift 6.2+ baseline.
- [ ] Strict concurrency policy is explicit and enabled at the intended targets.
- [ ] No new unreviewed `DispatchQueue`, `Task.detached`, or unsafe shared mutable state remains.
- [ ] `make build-agent`, `make test-sensitive`, `make arch-check`, `make lint`, and `make build-test` results are recorded.
- [ ] Thermo review has no unresolved Critical/Medium findings.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Enabling the mode produces widespread diagnostics whose ownership cannot be determined without redesigning multiple modules.
- A fix requires changing audio callback behavior or persistence semantics beyond the cited diagnostics.
- The installed toolchain cannot compile the selected language mode.
- Any concurrency fix requires `@unchecked Sendable` without a lock/ownership proof.

## Maintenance notes

Observation migration in Plan 040 should build on the actor-isolation policy established here. Reviewers must reject fixes that merely silence diagnostics with `@preconcurrency`, `@unchecked Sendable`, or broad `@MainActor` annotations on audio/data services.
