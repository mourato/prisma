---
name: swift-conventions
description: This skill should be used when the user asks to "apply Swift style conventions", "improve type safety", "refactor API naming", or "organize Swift modules".
---

# Swift Coding Conventions

## Overview

Standards for consistency, readability, and type safety in this Swift codebase.

## Scope Boundaries

- Use this skill for Swift-specific conventions and type-safety patterns.
- Use `../code-quality/SKILL.md` for broader readability and maintainability guidance that is not language-specific.

## 1. Type Safety & Modeling

- **Avoid Any**: Prefer strong types over `Any` or `NSObject`.
- **Result Type**: Use `Result<Success, Failure>` for fallible operations.
- **Enums**: Model complex states with enums and associated values for exhaustive handling.
- **Codable**: Use `Codable` for structured serialization/deserialization.

## 2. Language Patterns

- **Optionals**: Avoid force unwrap (`!`); prefer `guard let` or `if let`.
- **Properties**: Use computed properties for simple transformations.
- **Closures**: Mark closures as `@Sendable` across concurrency boundaries.

## 3. Organization & Style

- **Naming**: `lowerCamelCase` for members and `UpperCamelCase` for types.
- **Imports**: Keep imports minimal and consistently ordered.
- **Standard Library**: Prefer native Swift APIs over heavier Foundation alternatives when equivalent.
- **Resources**: Use `Bundle.module` for Swift Package resources.
