---
name: code-quality
description: This skill should be used when the user asks to "improve code readability", "rename for clarity", "refactor duplicated logic", or "apply clean code conventions".
---

# Code Quality Standards

## Overview

Fundamental rules for writing clean, self-explanatory, and maintainable code.

## Scope Boundaries

- Use this skill for language-agnostic readability and maintainability principles.
- Use `../swift-conventions/SKILL.md` when the task is specifically about Swift syntax, type-system idioms, or Swift API style.

## 1. Function & Variable Naming

- **Clarity**: Name variables and functions with descriptive intent (e.g., `userData` instead of `data`).
- **Convention**: Use `lowerCamelCase` for variables and functions; `UpperCamelCase` for types and protocols.
- **Conciseness**: Avoid abbreviations except for universally accepted ones (`id`, `ui`, `ai`).

## 2. Code Structure

- **Small Functions**: Keep functions focused on a single responsibility. Aim for a maximum of 20-30 lines.
- **Flattened Logic**: Use `guard` statements and early returns to avoid deeply nested `if` blocks.
- **Comments**: Explain the why (design decisions, edge cases), not the obvious what.

## 3. Tooling & Verification

- **Linting**: Ensure `swiftlint` and `swiftformat` run before commit.
- **Refactoring**: Apply the Boy Scout Rule and leave code cleaner than found.
- **Review Size**: Keep changes small and atomic to improve review quality.
