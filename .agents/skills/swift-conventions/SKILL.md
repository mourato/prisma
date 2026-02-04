---
name: swift-conventions
description: Swift-specific coding conventions, type safety patterns, and module patterns. Covers naming, imports, enums, and resource access. Use as a general style guide.
---

# Swift Coding Conventions

## Overview

Standards designed for consistency, readability, and type safety across the Swift codebase.

## 1. Type Safety & Modeling

- **Avoid Any**: Use strong types instead of `Any` or `NSObject`.
- **Result Type**: Use `Result<Success, Failure>` for modeling operations that can fail.
- **Enums**: Model complex states with enums and associated values to ensure exhaustive handling.
- **Codable**: Use `Codable` for all data serialization and deserialization.

## 2. Language Patterns

- **Optionals**: Avoid force unwrapping (`!`). Prefer `guard let` or `if let`.
- **Properties**: Use computed properties for simple data transformations instead of auxiliary methods.
- **Closures**: Mark closures as `@Sendable` when passed across concurrency boundaries.

## 3. Organization & Style

- **Naming**: `lowerCamelCase` for properties and functions; `UpperCamelCase` for types.
- **Imports**: Group imports alphabetically (e.g., `CoreData`, `Foundation`, `OSLog`).
- **Standard Library**: Prefer native Swift types and methods over Foundation equivalents where possible.
- **Resources**: Use `Bundle.module` when accessing resources within Swift Packages.
