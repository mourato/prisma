---
name: code-quality
description: General code quality standards including naming conventions, function size, and best practices for readability and maintainability. Use during development and code review.
---

# Code Quality Standards

## Overview

Fundamental rules for writing clean, self-explanatory, and maintainable Swift code.

## 1. Function & Variable Naming

- **Clarity**: Name variables and functions with descriptive intent (e.g., `userData` instead of `data`).
- **Convention**: Use `lowerCamelCase` for variables and functions; `UpperCamelCase` for types and protocols.
- **Conciseness**: Avoid abbreviations except for universally accepted ones (`id`, `ui`, `ai`).

## 2. Code Structure

- **Small Functions**: Keep functions focused on a single responsibility. Aim for a maximum of 20-30 lines.
- **Flattened Logic**: Use `guard` statements and early returns to avoid deeply nested `if` blocks.
- **Comments**: Write comments that explain the "Why" (design decisions, edge cases) rather than the "What" (which should be obvious from the code).

## 3. Tooling & Verification

- **Linting**: Ensure `swiftlint` and `swiftformat` are run before any commit.
- **Refactoring**: Apply the "Boy Scout Rule"—leave the code slightly better than you found it.
- **Review Size**: Keep code changes small and atomic to ensure effective review.
