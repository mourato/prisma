# AGENTS.md - Meeting Assistant Development Guide

This file provides guidelines and commands for AI agents working on this codebase. See `.agent/rules/` for detailed rules on specific topics.

## Build Commands

```bash
# Generate Xcode project (required after modifying project.yml)
xcodegen generate

# Build Debug (opens in Xcode)
open MeetingAssistant.xcodeproj && echo "Press ⌘R to run"

# Build Release from command line
./scripts/build-release.sh

# Create DMG installer
./scripts/create-dmg.sh
```

## Lint & Format Commands

```bash
# Run linting only
./scripts/lint.sh

# Auto-fix lint and formatting issues
./scripts/lint-fix.sh

# Requirements: SwiftLint and SwiftFormat must be installed
brew install swiftlint swiftformat
```

## Testing

```bash
# Build and run all tests
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS' CODE_SIGN_IDENTITY="-"

# Run a single test file
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS' -only-testing:MeetingAssistantCoreTests/PartialBufferStateTests

# Run a specific test
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS' -only-testing:MeetingAssistantCoreTests/RecordingViewModelTests/testInitialState

# Run tests with verbose output
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" VERBOSE=1
```

## Architecture (MVVM + Clean)

- Use MVVM or Clean Architecture separating presentation, data, and network layers
- Inject dependencies via constructors — avoid `.shared` singletons in ViewModels
- Prefer Protocol-Oriented Programming — create protocols for abstractions
- Keep ViewModels lean, delegate heavy logic to services and repositories
- Reference: `.agent/rules/architecture.md`

## Code Style

### Naming
- Variables/functions: `lowerCamelCase`
- Types: `UpperCamelCase`
- Constants: `kConstantName` or `lowerCamelCase` for local
- Avoid abbreviations except: `id`, `ui`, `ai`, `ok`, `at`, `to`

### Imports
- Order alphabetically (e.g., `CoreML, Foundation, OSLog`)
- Group framework imports before local imports

### Formatting (SwiftFormat)
- 4 spaces indentation
- K&R braces (else on same line)
- Always use trailing commas
- Use `Void` instead of `()`
- Insert explicit `self`
- Semicolons inline
- Wrap arguments before first element

### Functions & Clean Code
- Maximum 20 lines per function — single responsibility
- Use `guard` for early returns, flatten conditionals
- Document public APIs with `///` comments
- Reference: `.agent/rules/clean-code.md`

### Type Safety
- Avoid `Any` and `NSObject` — they compromise Swift's type system
- Use `Result<Success, Failure>` for type-safe error returns
- Model complex states with enums containing associated values
- Avoid force unwrapping — use `guard let` and `if let`
- Implement `Codable` for JSON instead of generic dictionaries
- Reference: `.agent/rules/type-security.md`

### Lifecycle & Memory
- Choose reference types (classes) for shared identity, value types (structs) for immutable data
- Capture `self` as `weak` in closures — `[weak self] in`
- Implement `deinit` to release resources explicitly
- Avoid retain cycles by tracking weak references
- Reference: `.agent/rules/lifecycle-and-memory.md`

## Error Handling

- Define custom error types conforming to `Error`
- Propagate errors with `try`, avoid `try?` by default
- Use `try!` only when failure is impossible
- Log context with structured logging (use `Logger` from os.log)
- Never use `print()` or `NSLog()` — use `AppLogger`
- Reference: `.agent/rules/error-handling.md`

## Concurrency

- Use `Actor` or `@MainActor` for thread safety
- Avoid `@unchecked Sendable` unless absolutely necessary
- Prefer `async/await` over callbacks
- Mark closures passed between threads as `@Sendable`
- Reference: `.agent/rules/concurrency.md`

## Audio Real-Time (Critical)

- **Zero Allocation**: NEVER allocate memory (Classes, Arrays, Strings) inside audio callbacks
- Use pre-allocated Ring Buffer during initialization
- Use `memcpy` via `UnsafeMutableBufferPointer` for efficient copying
- **Bounds Checking**: Always use `min(source.count, dest.count)` to prevent buffer overflows
- **Lock Safety**: NEVER use `NSLock` or `@MainActor` in real-time audio callbacks
- Use `OSAllocatedUnfairLock` (spinlock equivalent) for nanosecond blocking
- Reference: `.agent/rules/audio-realtime.md` and `docs/ARCHITECTURE.md`

## Performance

- Use lazy initialization (`lazy var`) for expensive properties
- Perform heavy operations on background threads — `DispatchQueue.global().async`
- Update UI exclusively on main thread — `DispatchQueue.main.async`
- Implement cache with explicit expiration strategy, never indefinite
- Profile before optimizing — use Instruments to identify real bottlenecks
- Reference: `.agent/rules/performance.md`

## UI/UX (SwiftUI)

- Use native controls following Apple Human Interface Guidelines
- Support Dark Mode with semantic colors (`Color(.windowBackgroundColor)`, `Color.primary`)
- Prefer `WindowGroup` or `Settings` scenes over custom windows
- Use `NavigationSplitView` for sidebar apps with correct `columnVisibility`
- Ensure windows are resizable and respect traffic light buttons
- Reference: `.agent/rules/ui_ux.md`

## Menu Bar Apps (NSStatusItem)

- Right-click on `NSStatusItem` should show context menu
- Use `showContextMenu()` pattern that closes any open popover first
- Store references to dynamic menu items to update titles based on state
- Use factory methods like `createMenuItem(key:action:keyEquivalent:)` to reduce boilerplate
- UI state (icons, menu titles) should update together using a single method
- Reference: `.agent/rules/menubar.md`

## Localization

- Use `Bundle.module` in Swift Packages — `Bundle.main` won't find resources
- Use `NSLocalizedString("Key", bundle: .module, comment: "...")` for localization
- In SwiftUI, use `Text("Key", bundle: .module)` when bundle isn't inferred automatically
- Never hardcode UI strings — extract to `Localizable.strings`
- Use descriptive keys in snake_case (e.g., `settings_api_key_placeholder`)
- Reference: `.agent/rules/localization.md`

## Accessibility

- All `accessibilityDescription` MUST use `NSLocalizedString` with correct bundle
- Key convention: `*.accessibility.*` (e.g., `menubar.accessibility.recording`)
- Describe *purpose* or *state*, not just labels ("Recording in progress" vs "Recording")
- Reference: `.agent/rules/localization.md`

## Logging

- Use `AppLogger` from `MeetingAssistantCore.Logging`
- Log category: `LogCategory` enum (audio, transcription, ui, etc.)
- Log level: `.debug`, `.info`, `.warning`, `.error`

## Security

- Never store secrets in source code — use environment variables or servers
- Validate all user input and network data
- Implement biometric authentication correctly with `LocalAuthentication` for sensitive data
- Keep App Transport Security enabled — HTTPS required in production
- Reference: `.agent/rules/security.md`

## Networking

- Use `URLSession` as default — native and sufficient for most cases
- Configure realistic timeouts (5–30 seconds typical)
- Implement retry logic for transient failures (timeouts, 5xx errors)
- Always validate HTTPS certificates in production
- Reference: `.agent/rules/network.md`

## Data Persistency

- Choose storage: `UserDefaults` for lightweight preferences, Core Data for complex models
- Store sensitive data (passwords, tokens) in Keychain, never in plain defaults or disk
- Plan schema migrations from the start
- Reference: `.agent/rules/data-persistency.md`

## External Dependencies

- Minimize dependencies — each package adds maintenance risk
- Prefer Swift Package Manager as the standard dependency manager
- Specify versions explicitly — use `.upToNextMajor` instead of wildcard
- Audit packages regularly for vulnerabilities and updates
- Reference: `.agent/rules/external-dependencies.md`

## Testing

- Isolate unit tests by mocking all external dependencies
- Maintain coverage above 80% in critical layers
- Avoid UI tests — they are fragile and slow; use sparingly
- Mock networking with libraries like OHHTTPStubs for deterministic tests
- Reference: `.agent/rules/testing.md`

## Known Limitations

- Keep `docs/KNOWN_LIMITATIONS.md` always updated
- When implementing new functionality, explicitly document technical, performance, or UI limitations
- For each limitation, include context with the reason (e.g., time constraint) and approximate date
- Reference: `.agent/rules/known-limitations.md`

## Project Structure

- `App/` — Main app target (entry point, Info.plist, entitlements)
- `Packages/MeetingAssistantCore/` — Core library with Models, Services, ViewModels, Views, Tests
- `docs/` — Documentation including ARCHITECTURE.md and BEST_PRACTICES.md
- `.agent/rules/` — Detailed rules for agents working on this codebase

## MARK Comments

- Use format: `// MARK: - Section Name`
- Group code logically within files
