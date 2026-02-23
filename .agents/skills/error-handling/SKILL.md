---
name: error-handling
description: This skill should be used when the user asks to "design error types", "improve error propagation", "add recovery paths", or "standardize error logging".
---

# Error Handling & Propagation

## Overview

Standards for managing failure states in a predictable, informative, and safe manner.

## 1. Defining Errors

- **Custom Enums**: Define domain-specific error types using the `Error` protocol and `LocalizedError` for user-facing messages.
- **Context**: Use associated values in enums to provide detailed context about the failure (e.g., `case networkError(statusCode: Int)`).

## 2. Propagation & Handling

- **Explicitness**: Propagate errors where it makes sense. Avoid silent failures with `try?` by default.
- **Safe Unwrapping**: Avoid force unwrapping (`!`). Use `guard let` or `if let` for optionals.
- **Exhaustive Catching**: Handle errors thoroughly in the Presentation layer to provide meaningful feedback to the user.

## 3. Logging & Recovery

- **Structured Logging**: Log errors with full context (operation name, error type, parameters). Avoid vague messages like "Something went wrong".
- **Recovery Logic**: Implement retry mechanisms for transient failures (e.g., network timeouts) where appropriate.
- **Graceful Failure**: Ensure the application remains in a stable state even after an error occurs.
