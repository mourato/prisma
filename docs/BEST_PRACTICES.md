# Project Best Practices

## High-Performance Audio (Real-Time)

### Zero Allocation Policy
- **Rule**: Do not allocate memory (Classes, Arrays, Strings) inside the audio render callback (`AVAudioSourceNode`, `Process Tap`).
- **Why**: Allocations can trigger locks or garbage collection, causing audio dropouts (glitches).
- **Solution**: Pre-allocate buffers (e.g., Ring Buffer) during initialization.

### Efficient Copying
- **Rule**: Avoid manual `for` loops for copying audio samples between buffers.
- **Solution**: Use `memcpy` via `UnsafeMutableBufferPointer` to move memory blocks efficiently.
- **Risk**: Requires strict bounds checking (`min(source.count, dest.count)`) to prevent buffer overflows.

## Concurrency

### Lock Safety
- **Rule**: NEVER use `NSLock` or `@MainActor` inside a real-time audio callback.
- **Solution**: Use `OSAllocatedUnfairLock` (Spinlock equivalent) which blocks for nanoseconds rather than milliseconds.
- **Reference**: `SystemAudioRecorder.CallbackStorage`.

### Sendable Closure Protocol
- **Rule**: Closures passed between threads (especially for callbacks) MUST be marked `@Sendable`.
- **Why**: Ensures compiler verification of thread safety and prevents capturing mutable non-thread-safe state.

## UI/UX Patterns

### Menu Bar Apps (NSStatusItem)
- **Context Menu Behavior**: Right-click on `NSStatusItem` should show a context menu. Use `showContextMenu()` pattern that closes any open popover first.
- **Dynamic Menu Items**: Store a reference to dynamic menu items (`startStopMenuItem`) to update their title based on state changes.
- **Helper Methods for Menu Construction**: Use factory methods like `createMenuItem(key:action:keyEquivalent:)` to reduce boilerplate when building menus.

### Consistent UX
- **Popover Management**: If `showContextMenu()` closes the popover, individual menu actions should NOT redundantly call `popover?.performClose(nil)`.
- **State Reflection**: UI state (icons, menu titles) should update together. Use a single method like `updateStatusIcon(isRecording:)` to synchronize all visual elements.

## Localization

### Accessibility (VoiceOver)
- **Rule**: All `accessibilityDescription` parameters MUST use `NSLocalizedString` with the correct bundle.
- **Naming**: Use `*.accessibility.*` keys (e.g., `menubar.accessibility.recording`).
- **Context**: Describe *purpose* or *state*, not just labels. Example: "Recording in progress" vs. "Recording".

### Cross-Module Bundle Access
- **Rule**: When the App target needs localized strings from a framework (e.g., `MeetingAssistantCore`), use a `public static var safeModule: Bundle` pattern.
- **Implementation**: Use `#if SWIFT_PACKAGE` to conditionally return `Bundle.module` (SPM) or `Bundle.main` (Xcode).
- **DRY**: Store the bundle in a `lazy var localizationBundle` to avoid repeated calls.
