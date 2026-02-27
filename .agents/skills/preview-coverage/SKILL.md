---
name: preview-coverage
description: This skill should be used when the user asks to "add #Preview", "improve preview state coverage", or "validate SwiftUI previews" in MeetingAssistantCoreUI.
---

# Preview Coverage

## Overview

Standards for creating and maintaining SwiftUI previews across `MeetingAssistantCoreUI`.

## When to Use

Activate this skill when:
- Creating a new SwiftUI `View`
- Refactoring existing UI components
- Adding settings screens or Design System components
- Reviewing UI quality gates before merge

## Required Rules

1. Every `struct ...: View` must include at least one `#Preview`.
2. Prefer multiple previews for meaningful states (for example: idle/loading/success/error, collapsed/expanded).
3. Avoid side effects in previews (network, downloads, long-running tasks).
4. If a view triggers startup work, gate it for previews using `PreviewRuntime.isRunning`.
5. If bindings are needed, use local preview state wrappers (for example `PreviewStateContainer`).
6. For AppKit controllers, preview the underlying SwiftUI rendering surface.
7. Verify keyboard/focus behavior for settings and drill-down surfaces when previews include interactive controls.

## Project Utilities

- Preview runtime guard:
  - `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/PreviewSupport/PreviewRuntime.swift`
- Stateful preview helper:
  - `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/PreviewSupport/PreviewStateContainer.swift`

## Verification

Run:

```bash
make preview-check
```

The check fails if any SwiftUI view under `MeetingAssistantCoreUI` is missing preview coverage.

## References

- `scripts/preview-check.sh`
- `.agents/skills/swiftui-patterns/SKILL.md`
