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
