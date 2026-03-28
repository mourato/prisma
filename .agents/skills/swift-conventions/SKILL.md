---
name: swift-conventions
description: This skill should be used when the user asks to "apply Swift style conventions", "improve type safety", "refactor API naming", or "organize Swift modules".
---

# Swift Coding Conventions

## Overview

Standards for consistency, readability, and type safety in this Swift codebase.
This skill is the human-readable companion to `.swiftlint.yml`.

## Scope Boundaries

- Use this skill for Swift-specific conventions and type-safety patterns.
- Use `../code-quality/SKILL.md` for broader readability and maintainability guidance that is not language-specific.

## 1. SwiftLint-Aligned Writing Rules

Use this section as the practical "how to write code here" reference. Keep it aligned with `.swiftlint.yml`.

### 1.1 Size and Complexity Budgets

- File size: SwiftLint warning at 600 lines and error at 1000 lines. Project policy is stricter: keep files at or below 600 lines.
- Function body size: warning at 60 lines, error at 100 lines.
- Type body size: warning at 400 lines, error at 600 lines.
- Cyclomatic complexity: warning at 15, error at 25.
- Preferred response when approaching limits: split responsibilities, extract helpers/use cases, and simplify control flow.

### 1.2 Preferred Idioms (Opt-In Rules)

- Use `.isEmpty` instead of comparing with `""`.
- Prefer `first(where:)` over manual loops for first-match retrieval.
- Always include a message in `fatalError(...)` so crashes are diagnosable.
- Avoid explicit `.init` when type context is clear.
- Avoid redundant `??` when the left-hand side cannot be `nil`.
- Use `_` separators in larger numeric literals for readability.
- Remove unnecessary parentheses in closure arguments.
- Keep multi-line call-site parameters vertically aligned.

### 1.3 Formatting and Lint-Disable Hygiene

- Trailing commas are mandatory in multi-line collections and argument lists.
- Keep `swiftlint:disable` scopes narrow and justified with a short comment.
- Even though blanket/superfluous disable command checks are currently disabled in lint config, do not use broad disables.

### 1.4 Team Conventions Not Strictly Enforced by SwiftLint

- Prefer descriptive names even though `identifier_name` is disabled.
- Do not merge unresolved TODO markers even though `todo` is disabled.
- Keep nesting shallow and use early exits even though `nesting` is disabled.
- Avoid implicitly unwrapped optionals unless required by framework integration, then document why.

### 1.5 File and Folder Naming

- Keep Swift filenames in `PascalCase`.
- When one type spans multiple files, colocate them in a directory named after the owning type.
- Canonical pattern: `Bucket/TypeName/TypeName.swift` plus sibling files that keep a unique basename per target, such as `RecordingManagerRetry.swift`, `AppSettingsStoreDefaults.swift`, `MeetingAppUI.swift`, or `FloatingRecordingIndicatorViewPreview.swift`.
- `.swiftlint.yml` disables `file_name` so colocated concern files can keep explicit owner-prefixed basenames when needed.
- Do not use `Type+Concern.swift` filenames.
- Public module names may stay verbose (`MeetingAssistantCoreUI`) even when filesystem directories are short (`Sources/UI`).

## 2. Type Safety & Modeling

- **Avoid Any**: Prefer strong types over `Any` or `NSObject`.
- **Result Type**: Use `Result<Success, Failure>` for fallible operations.
- **Enums**: Model complex states with enums and associated values for exhaustive handling.
- **Codable**: Use `Codable` for structured serialization/deserialization.

## 3. Language Patterns

- **Optionals**: Avoid force unwrap (`!`); prefer `guard let` or `if let`.
- **Properties**: Use computed properties for simple transformations.
- **Closures**: Mark closures as `@Sendable` across concurrency boundaries.

## 4. Organization & Style

- **Naming**: `lowerCamelCase` for members and `UpperCamelCase` for types.
- **Imports**: Keep imports minimal and consistently ordered.
- **Standard Library**: Prefer native Swift APIs over heavier Foundation alternatives when equivalent.
- **Resources**: Use `Bundle.module` for Swift Package resources.
