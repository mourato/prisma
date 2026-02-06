---
name: localization
description: This skill should be used when working with localization, accessibility, VoiceOver, or multilingual support in Swift Packages.
---

# Localization and Accessibility

## Overview

Complete guide for internationalization (i18n) and accessibility (a11y) for the Meeting Assistant.

## When to Use

Activate this skill when working with:
- `Bundle.safeModule` resource resolution
- `"some.key".localized` / `"some.key".localized(with: ...)`
- Accessibility modifiers
- VoiceOver support

## Key Concepts

### Resource Loading

**CRITICAL**: This project centralizes localization bundle resolution in `Bundle.safeModule` (see `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Utilities/BundleExtension.swift`).

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

Ao adicionar ou remover textos na interface, é importante tratar eles de maneira adequada: ou cuidando da correta localização ou fazendo a sanitização do que for removido.

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

- [BundleExtension.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Utilities/BundleExtension.swift)
- [Localizable.strings](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Resources/en.lproj/Localizable.strings)
- [Apple Accessibility Guide](https://developer.apple.com/documentation/accessibility)
