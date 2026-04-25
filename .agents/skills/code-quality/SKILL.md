---
name: code-quality
description: This skill should be used when the user asks to "improve code readability", "rename for clarity", "refactor duplicated logic", or "apply clean code conventions".
---

# Code Quality Standards

## Role

Use this skill as the canonical owner for language-agnostic readability and maintainability guidance in Prisma.

- Own naming clarity, decomposition, duplication reduction, and comment quality.
- Keep code-quality advice independent from language-specific syntax details.
- Delegate Swift-specific idioms and style rules to the Swift conventions owner.

## When to Use

Use this skill when the task is about improving readability, renaming for clarity, refactoring duplicated logic, or applying clean-code conventions.

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

- **Small Functions**: Keep functions focused on a single responsibility and split logic when readability drops.
- **Size Limits**: For Swift files, use the budgets defined in `../swift-conventions/SKILL.md` (sourced from `.swiftlint.yml`) instead of ad-hoc line limits.
- **Flattened Logic**: Use `guard` statements and early returns to avoid deeply nested `if` blocks.
- **Comments**: Explain the why (design decisions, edge cases), not the obvious what.

## 3. Tooling & Verification

- **Linting**: Ensure `swiftlint` and `swiftformat` run before commit.
- **Refactoring**: Apply the Boy Scout Rule and leave code cleaner than found.
- **Review Size**: Keep changes small and atomic to improve review quality.

## Related Skills

- `../swift-conventions/SKILL.md`
- `../code-review/SKILL.md`

## References

- `../swift-conventions/SKILL.md`
- `../code-review/SKILL.md`
