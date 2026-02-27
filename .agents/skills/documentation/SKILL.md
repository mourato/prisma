---
name: documentation
description: This skill should be used when the user asks to "write/update documentation", "add DocC comments", "improve MARK organization", or "research API docs".
---

# Documentation Standards

## Overview

Detailed guidance on documenting Swift code and using external tools to research library dependencies.

## 1. DocC Best Practices

- **Triple-Slash**: Use `///` for all public API documentation.
- **Format**: Follow standard Swift documentation format (Summary, Parameters, Returns, Throws).
- **Auto-Generation**: Ensure documentation is structured to be compatible with DocC generation.

## 2. External Research (context7)

**CRITICAL**: Use the `context7` toolset to access up-to-date documentation for libraries and frameworks.

### When to use context7
- When working with unfamiliar libraries or frameworks.
- When seeking code examples for specific third-party APIs.
- When verifying implementation best practices for external dependencies.

### Workflow
1. **Resolve ID**: Use `resolve-library-id` from `context7` to find the correct library identifier.
2. **Query**: Use `query-docs` to ask specific implementation questions.
3. **Validate**: Always test and validate code snippets obtained from documentation in the project context.

## 3. Tool-Agnostic Principles

- **Clear Intent**: Documentation should explain the "Why" (intent, trade-offs) rather than just the "What".
- **Living Docs**: Keep `README.md` and `AGENTS.md` updated as the architecture evolves.
- **Known Limitations**: Document technical debt and constraints in GitHub issues (label `known-limitation`), not in root `docs/` files.

## Key Concepts

### DocC Syntax

Document public APIs with triple-slash comments and structured markup:

```swift
/// A struct representing a meeting recording.
///
/// This struct encapsulates all metadata and content of a recording,
/// including speaker identification and timestamp alignment.
///
/// ## Usage
/// ```swift
/// let recording = Recording(
///     id: UUID(),
///     title: "Team Meeting",
///     date: Date()
/// )
/// ```
public struct Recording: Identifiable, Codable {
    /// The unique identifier of the recording.
    public let id: UUID

    /// The title of the recorded meeting.
    public let title: String

    /// The date and time when recording started.
    public let date: Date

    /// The duration of the recording in seconds.
    public let duration: TimeInterval

    /// The transcribed text of the meeting.
    public let transcription: String?

    /// Initializes a new recording.
    ///
    /// - Parameters:
    ///   - id: The unique identifier. If nil, a new UUID will be generated.
    ///   - title: The meeting title.
    ///   - date: The recording date.
    ///   - duration: The duration in seconds.
    ///   - transcription: Optionally, the transcribed text.
    public init(
        id: UUID? = nil,
        title: String,
        date: Date,
        duration: TimeInterval,
        transcription: String? = nil
    ) {
        self.id = id ?? UUID()
        self.title = title
        self.date = date
        self.duration = duration
        self.transcription = transcription
    }

    /// Starts playback of the recording.
    ///
    /// - Throws: `RecordingError.notFound` if file doesn't exist.
    /// - Returns: The configured audio player.
    public func play() throws -> AudioPlayer {
        guard FileManager.default.fileExists(atPath: path) else {
            throw RecordingError.notFound
        }
        return AudioPlayer(url: path)
    }
}

/// Errors that can occur during recording operations.
public enum RecordingError: Error, LocalizedError {
    case notFound
    case corruptedFile
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "The recording file was not found."
        case .corruptedFile:
            return "The recording file is corrupted."
        case .permissionDenied:
            return "Permission denied to access the file."
        }
    }
}
```

## Code Organization

### MARK Comments

Use `// MARK:` to organize code into logical sections:

```swift
// MARK: - Properties

// MARK: - Initialization

// MARK: - Public Methods

// MARK: - Private Methods
```

### Protocol Extensions

```swift
// MARK: - Codable

extension Recording: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, date, duration, transcription
    }
}
```

---

## Context7 MCP Integration

Use Context7 MCP to get up-to-date documentation for external libraries and frameworks.

### When to Use Context7

- Working with unfamiliar libraries or frameworks
- Need code examples for specific APIs
- Verifying best practices for implementation
- Facing configuration or usage questions about dependencies

### How to Query

1. **Resolve library ID**: Use `mcp--context7--resolve-library-id`
2. **Query docs**: Use `mcp--context7--query-docs` with specific questions

```bash
# Example: Get Supabase documentation
mcp--context7--resolve-library-id(
  libraryName: "supabase",
  query: "Swift iOS authentication"
)

mcp--context7--query-docs(
  libraryId: "/supabase/supabase-js",
  query: "How to implement JWT authentication"
)
```

### Best Practices

- **Be specific** in queries (use cases, not generic topics)
- **Verify doc dates** - Context7 provides updated docs
- **Combine with existing code** - integrate with project patterns
- **Validate examples** in development environment

## References

- [Meeting.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Models/Meeting.swift)
- [Apple DocC Guide](https://developer.apple.com/documentation/docc)
