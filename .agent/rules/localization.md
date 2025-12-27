---
trigger: model_decision
description: When working with the interface (UI) of the app.
---

# Localization Guidelines

## Resource Loading in Swift Packages
- **Always use `Bundle.module`**: When working within a Swift Package, standard `Bundle.main` will not locate resources (strings, assets, colors) correctly. You must use the synthesized `Bundle.module`.
- **String Localization**: Use `NSLocalizedString("Key", bundle: .module, comment: "Comment")` for code-based localization.
- **SwiftUI**: Provide the bundle explicitly in SwiftUI views if they don't automatically infer it, or use the `Text("Key", bundle: .module)` initializer.

## String Management
- **Localizable.strings**: Maintain a single `Localizable.strings` file for each language in the package's `Resources` directory.
- **Don't Hardcode**: Never hardcode user-facing strings in UI code. Always extract them to the strings file.
- **Keys**: Use descriptive snake_case or camelCase keys that describe the UI element or purpose (e.g., `settings_api_key_placeholder`, `alert_error_title`).

## Formatting
- **Placeholders**: Use standard format specifiers (`%@`, `%d`) for dynamic content and ensure the arguments passed match the expected types.

## Accessibility (VoiceOver)
- **Localize Accessibility Descriptions**: All `accessibilityDescription` parameters on images, buttons, and interactive elements MUST use `NSLocalizedString` with the appropriate bundle.
- **Naming Convention**: Use `*.accessibility.*` keys (e.g., `menubar.accessibility.recording`, `button.accessibility.save`).
- **Context Matters**: Accessibility descriptions should describe the *purpose* or *state*, not just the label. Example: "Recording in progress" instead of just "Recording".

## Cross-Module Bundle Access
- **Use `Bundle.safeModule`**: When the App target needs localized strings from a framework (e.g., `MeetingAssistantCore`), use the `Bundle.safeModule` pattern.
- **Implementation**: Uses `#if SWIFT_PACKAGE` to conditionally return `Bundle.module` (SPM) or `Bundle.main` (Xcode).
- **DRY Principle**: Store the bundle reference in a `lazy var` property (e.g., `localizationBundle`) rather than calling `Bundle.safeModule` multiple times.

