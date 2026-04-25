---
name: swift-concurrency-expert
description: This skill should be used when the user asks to "fix Swift concurrency errors", "resolve actor isolation issues", "remediate Sendable diagnostics", or "upgrade to Swift 6.2 concurrency".
---

# Swift Concurrency Expert

## Role

Use this skill as the canonical owner for Swift concurrency diagnostics and remediation in Prisma.

- Own actor-isolation fixes, Sendable remediation, and compiler-driven concurrency triage.
- Keep concurrency fixes minimal, behavior-preserving, and explicit about ownership boundaries.
- Delegate conceptual-only concurrency teaching to the concurrency bridge skill.

## Scope Boundary

- Use this skill for concrete Swift concurrency compiler issues and remediation.
- Use `../concurrency/SKILL.md` for conceptual guidance without concrete compiler remediation.

## When to Use

Use this skill when the user asks to fix Swift concurrency errors, resolve actor isolation issues, remediate Sendable diagnostics, or upgrade to Swift 6.2 concurrency.

## Overview

Review and fix Swift Concurrency issues in Swift 6.2+ codebases by applying actor isolation, Sendable safety, and modern concurrency patterns with minimal behavior changes.

## Scope in this repository

- Canonical skill for concurrency remediation and compiler-error driven fixes.
- Prioritize minimal behavioral changes and explicit safety boundaries.
- Pair with repo verification commands (`make test-strict`, `make test-agent`).

## Version compatibility mode

Use the following compatibility rules during triage:

- **Swift 6.2+ mode**: apply isolated conformances and approachable-concurrency guidance where enabled.
- **Swift 6.0/6.1 mode**: do not assume approachable concurrency or default actor isolation flags; prefer explicit `@MainActor` / actor boundaries and conservative Sendable fixes.
- Always verify actual project settings before applying 6.2-specific recommendations.

## Workflow

### 1. Triage the issue

- Capture the exact compiler diagnostics and the offending symbol(s).
- Check project concurrency settings: Swift language version (6.2+), strict concurrency level, and whether approachable concurrency (default actor isolation / main-actor-by-default) is enabled.
- Identify the current actor context (`@MainActor`, `actor`, `nonisolated`) and whether a default actor isolation mode is enabled.
- Confirm whether the code is UI-bound or intended to run off the main actor.
- If no compiler diagnostics were provided, first reproduce with strict checks (`make test-strict` or targeted strict run).

### 2. Apply the smallest safe fix

Prefer edits that preserve existing behavior while satisfying data-race safety.

Common fixes:
- **UI-bound types**: annotate the type or relevant members with `@MainActor`.
- **Protocol conformance on main actor types**: make the conformance isolated (e.g., `extension Foo: @MainActor SomeProtocol`).
- **Global/static state**: protect with `@MainActor` or move into an actor.
- **Background work**: move expensive work into a `@concurrent` async function on a `nonisolated` type or use an `actor` to guard mutable state.
- **Sendable errors**: prefer immutable/value types; add `Sendable` conformance only when correct; avoid `@unchecked Sendable` unless you can prove thread safety.

### 3. Validate and report

- Re-run strict checks and impacted tests after each fix.
- Report outcomes with before/after diagnostics (error removed, warning count reduced).
- Call out any remaining `@unchecked Sendable` or `Task.detached` usage that requires follow-up audit.


## Reference material

- See `references/swift-6-2-concurrency.md` for Swift 6.2 changes, patterns, and examples.
- See `references/approachable-concurrency.md` when the project is opted into approachable concurrency mode.
- See `references/swiftui-concurrency-tour-wwdc.md` for SwiftUI-specific concurrency guidance.

## 2026-03 Operational Update

### Repository Concurrency Hotspots

Start triage in these areas first:

- Onboarding shortcut formatting and view model updates (UI-bound logic).
- Global shortcut backend callbacks and bridge points to UI services.
- Recording lifecycle transitions that mix background work and UI state.

### Fast Triage Checklist

1. Identify the exact failing symbol and actor context.
2. Keep UI entry points `@MainActor`; avoid broad actor annotations on non-UI services.
3. Convert callback aliases to `@Sendable` where cross-thread execution is expected.
4. Prefer isolating mutable shared state in a dedicated actor over lock scattering.
5. Validate with `make test-strict` (or targeted strict run) plus `make test-agent`.

## 2026-03-04 Progression Drill

### New Evidence

- `13acce3`: sendability fixes in `AudioMerger` and `AudioRecorder+Diagnostics`.
- `9415604`: sendable closure fixes in `AudioRecorder`.
- `0040ca8`: `nonisolated` adjustment in performance metric path.

### Skill Deepening Focus

1. Build a repeatable triage template for `@Sendable` closure capture violations in audio callbacks.
2. Require actor-context mapping in every fix note: symbol, current isolation, target isolation, reason.
3. Add a short decision rule for `@MainActor` vs `nonisolated` in cross-module utility methods.
4. Validate each remediation with strict checks plus targeted audio-related tests when available.

## 2026-03-05 Progression Drill

### New Evidence

- `04bbb55`, `d0cdff6`, and `0c32f13` fixed actor-isolation errors in settings and overlay/UI support paths.
- `b032ae6` addressed a compiler-crash-prone concurrency pattern in `RecordingManager` defaults.
- Isolation fixes continued outside audio-only scope, especially in UI service factories.

### Skill Deepening Focus

1. Add a required "factory isolation review" step for default-provider builders and closure factories.
2. Prefer isolation-safe API reshaping (remove cross-actor callback surfaces) before adding broad annotations.
3. Track and document compiler-instability signatures separately from semantic actor errors to avoid repeating crash-inducing rewrites.
4. Validate UI isolation fixes with strict checks plus focused settings/onboarding tests whenever touched.

## 2026-03-06 Progression Drill

### New Evidence

- `e2c36b6` moved mic diagnostics logging to the main actor, indicating cross-actor observability pressure in audio paths.
- `918243b` delayed floating-indicator prewarming, showing lifecycle work continues to intersect actor ownership decisions.
- `094d280` implemented launch visibility recovery in app lifecycle code where actor context drift can regress startup behavior.

### Skill Deepening Focus

1. Add a mandatory "diagnostics isolation map" in fixes: logging callsite actor, state owner actor, and hop direction.
2. Default to isolating observability/writeback paths first (logging/metrics/UI status) before widening isolation on hot-path logic.
3. For lifecycle startup changes, require one explicit check that actor hops do not reorder visibility/state recovery events.
4. Pair strict-concurrency validation with one targeted runtime path (`launch -> status item visible -> indicator transition`) when isolation touches lifecycle/UI boundaries.
