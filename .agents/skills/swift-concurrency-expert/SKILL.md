---
name: swift-concurrency-expert
description: Swift Concurrency review and remediation for Swift 6.2+. Use when asked to review Swift Concurrency usage, improve concurrency compliance, or fix Swift concurrency compiler errors in a feature or file.
---

# Swift Concurrency Expert

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
