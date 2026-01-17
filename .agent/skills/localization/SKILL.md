---
name: Localization
description: This skill should be used when working with "localization", "internationalization", "i18n", "Bundle.module", "NSLocalizedString", "accessibility", "VoiceOver", or implementing multilingual support in Swift Packages.
---

# Localization and Accessibility

## Overview

Complete guide for internationalization (i18n) and accessibility (a11y) for the Meeting Assistant.

## When to Use

Activate this skill when working with:
- `Bundle.module` resource loading
- `NSLocalizedString`
- `Text("Key", bundle: .module)`
- Accessibility modifiers
- VoiceOver support

## Key Concepts

### Resource Loading in Swift Packages

**CRITICAL**: Use `Bundle.module` in Swift Packages:

```swift
// ✅ CORRECT - Swift Package
Text("settings_api_key_placeholder", bundle: .module)
NSLocalizedString("menubar.accessibility.recording", bundle: .module, comment: "Recording status")

// ❌ WRONG - Bundle.main doesn't work in frameworks
Text("settings_api_key_placeholder", bundle: .main)
```

### Safe Bundle Access

Create a fallback for safer resource loading:

```swift
extension Bundle {
    static var safeModule: Bundle {
        guard let module = Bundle.module else {
            return Bundle.main
        }
        return module
    }
}

// Usage
Text("key", bundle: .safeModule)
```

## Localization Patterns

### String Management

**NEVER** hardcode UI strings:

```swift
// ❌ WRONG
Text("Record")

// ✅ CORRECT
Text("recording.start", bundle: .module)
```

### Key Convention

Use descriptive `snake_case` keys:

```swift
// Good keys
"recording.start"              // Start recording
"recording.stop"               // Stop recording
"recording.in_progress"        // Recording in progress
"settings.api_key.placeholder" // API key placeholder
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

- [Localizable.strings](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Resources/en.lproj/Localizable.strings)
- [Apple Accessibility Guide](https://developer.apple.com/documentation/accessibility)
