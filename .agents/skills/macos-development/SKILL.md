---
name: macos-development
description: This skill should be used when the user asks to "implement a macOS feature", "integrate SwiftUI with AppKit", "fix macOS lifecycle issues", or "apply platform-specific patterns".
---

# macOS Development Standards

## Role

Use this skill as the canonical implementation reference for macOS Swift/SwiftUI/AppKit work in this repository.

## Scope Boundary

- This skill owns implementation guidance for platform lifecycle, architecture usage, UI integration, and system APIs.
- This skill does not replace specialist skills:
  - `native-app-designer` for primary UI/UX direction and experience analysis
  - `quality-assurance` for verification lanes and merge gates
  - `swift-concurrency-expert` for Swift 6.2 diagnostics/remediation
  - `swiftui-performance-audit` for SwiftUI runtime bottlenecks
  - `swiftui-animation` for advanced animation systems

## Core Standards

### Memory and Lifecycle

- Use value/reference semantics intentionally (`struct` vs `class`).
- Prevent retain cycles in escaping closures.
- Release observers, taps, and file handles deterministically.
- Keep side effects bounded to lifecycle entry points.

### Platform Integration

- Follow native macOS interaction patterns.
- Keep accessibility labels/actions complete for interactive UI.
- Respect sandbox and entitlement constraints.
- Use AppKit bridging only where SwiftUI is insufficient.

### Swift Concurrency Baseline

- Protect shared mutable state with actors.
- Keep UI-bound state under `@MainActor`.
- Check cancellation for long-running tasks.
- Avoid blocking primitives with async/await code paths.

## Implementation Workflow

1. Reusable-block scan first: `reuse -> extend -> create`.
2. Implement in small, verifiable slices.
3. Run scoped checks during development (`make build-agent`, targeted tests).
4. Apply required merge gates through `quality-assurance`.

## Command Baseline

```bash
make build-agent
make test-agent
make preflight-agent
```

For final merge in Medium/High risk work:

```bash
make build
make test
```

## Related Skills

- `../build-macos-apps/SKILL.md` (intake/router)
- `../native-app-designer/SKILL.md` (primary UI/UX direction)
- `../quality-assurance/SKILL.md` (verification policy)
- `../swiftui-patterns/SKILL.md`
- `../menubar/SKILL.md`
- `../audio-realtime/SKILL.md`
- `../localization/SKILL.md`
- `../swift-package-manager/SKILL.md`

## Reference Index

Use detailed references under `references/` for architecture, system APIs, testing, design system, and packaging topics.
