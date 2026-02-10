# SwiftUI Preview Guidelines

This document defines the preview standard for UI development in this repository.

## Goals

- Enable fast visual iteration directly in Xcode previews.
- Reduce regressions by covering multiple UI states per component.
- Keep preview code deterministic and free from side effects.

## Rules

- Every `struct ...: View` under `MeetingAssistantCoreUI` must have at least one `#Preview`.
- Interactive controls should use local preview state wrappers (for example `PreviewStateContainer`).
- Views with startup tasks must support side-effect suppression in previews.
- Prefer injecting view models/services when a view depends on external state.
- For AppKit controllers, preview the underlying SwiftUI surface.

## Side Effects In Preview

- Use `PreviewRuntime.isRunning` to disable network calls, downloads, and long-running startup work.
- Keep preview execution local and synchronous whenever possible.

## Verification

Run this command before opening a PR:

```bash
make preview-check
```

The check fails when a SwiftUI view exists without `#Preview`.
