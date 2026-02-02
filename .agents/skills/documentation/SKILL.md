---
name: Documentation
description: This skill should be used when working with "DocC", "documentation comments", "triple slash comments" (///), "API documentation", "Context7 MCP queries", or documenting Swift code with proper symbols and examples.
---

# Documentation with DocC

## Overview

Guide for consistent documentation using DocC (Documentation Compiler) and external library documentation via Context7 MCP.

## When to Use

Activate this skill when working with:
- `///` documentation comments
- DocC syntax and symbol documentation
- API documentation generation
- Context7 MCP queries for external library docs
- Symbol Graph files

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
