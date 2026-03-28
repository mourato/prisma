---
name: localization
description: This skill should be used when the user asks to "localize UI text", "update Localizable.strings", "improve VoiceOver labels", or "add accessibility localization".
---

# Localization and Accessibility

## Overview

Complete guide for internationalization (i18n) and accessibility (a11y) for the Prisma.

## When to Use

Activate this skill when working with:
- `Bundle.safeModule` resource resolution
- `"some.key".localized` / `"some.key".localized(with: ...)`
- Accessibility modifiers
- VoiceOver support

## Key Concepts

### Resource Loading

**CRITICAL**: This project centralizes localization bundle resolution in `Bundle.safeModule` (see `Packages/MeetingAssistantCore/Sources/Common/Utilities/BundleExtension.swift`).

```swift
// ✅ Standard (everywhere)
Text("settings.transcriptions.title".localized)
Text("permissions.granted_count".localized(with: granted, required))
let title = key.localized

// ✅ Formatting (respects Locale.current)
let message = "about.version".localized(with: AppVersion.current)

// ❌ Avoid in feature code (only allowed inside helpers)
NSLocalizedString("settings.transcriptions.title", comment: "")
```

Do not re-implement bundle lookup helpers in feature code. Always use the shared helpers.

## Localization Patterns

### String Management

**NEVER** hardcode UI strings:

```swift
// ❌ WRONG
Text("Record")

// ✅ CORRECT
Text("recording.start".localized)
```

When adding or removing UI text, ensure it is handled correctly: either by proper localization or by removing/sanitizing it safely.

### Mandatory Sanitization on UI Text Removal

If any user-facing text is removed from the interface, localization cleanup is required in the same task:

1. Remove orphaned keys from all supported locale files (`en.lproj`, `pt.lproj`, etc.).
2. Confirm no source references remain for the removed keys.
3. Keep locale files symmetric whenever applicable (no stale key in one language only).

This sanitization is mandatory, not optional.

### Key Convention

Use descriptive, dot-separated keys with `lower_snake_case` segments:

```swift
// Good keys
"recording.start"                   // Start recording
"recording.stop"                    // Stop recording
"recording.in_progress"             // Recording in progress
"settings.transcriptions.empty_desc" // Empty state description
```

## Accessibility (VoiceOver)

### Purpose Descriptions

Describe **what the UI does**, not just labels:

```swift
// ❌ WRONG - Label, not description
Button(action: {}) {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("Microphone")

// ✅ CORRECT - Purpose description
Button(action: {}) {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("recording.start.accessibility".localized)
.accessibilityHint("recording.start.hint.accessibility".localized)
.accessibilityAddTraits(.startsMediaSession)
```

### Accessibility Key Convention

Follow this pattern for consistent naming:

```swift
// Pattern: component.action.accessibility
"menubar.recording.start.accessibility" = "Start recording";
"menubar.recording.stop.accessibility" = "Stop recording";
"menubar.recording.status.accessibility" = "Recording status";
```

## References

- [BundleExtension.swift](../../../Packages/MeetingAssistantCore/Sources/Common/Utilities/BundleExtension.swift)
- [Localizable.strings](../../../Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings)
- [Apple Accessibility Guide](https://developer.apple.com/documentation/accessibility)
