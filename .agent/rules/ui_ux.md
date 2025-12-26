# UI/UX Guidelines

## Window Management
- **Standard Windows**: Prefer standard SwiftUI `WindowGroup` or `Settings` scenes over custom `NSWindow` management in `AppDelegate` unless strictly necessary for non-standard behavior (like floating panels).
- **NavigationSplitView**: Use `NavigationSplitView` for complex apps with sidebars. Configure `columnVisibility` to handle resizing behavior correctly.
- **Resizability**: Ensure windows are resizable and handle standard macOS traffic light buttons (close, minimize, maximize) naturally.

## Aesthetics
- **Native Look & Feel**: Follow Apple's Human Interface Guidelines (HIG). Use standard controls where possible.
- **Dark Mode**: Always support Dark Mode. Use semantic colors (`Color(.windowBackgroundColor)`, `Color.primary`) rather than fixed colors.

## General Style
- Use the latest visual styles and practices for macOS 26 Tahoe.
