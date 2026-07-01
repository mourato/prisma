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

## 2026-06-30 Progression Drill

### New Evidence

- `bac49a21` promoted structural simplification, reuse-before-create, file-size discipline, and aggressive complexity deletion into `AGENTS.md`.
- `650cc5d9` added `thermo-nuclear-code-quality-review` as a strict maintainability review mode for abstraction quality, giant files, and spaghetti-condition growth.
- `b953d6ad`, `68dd959f`, and `cdd980f5` showed the preferred pattern: extract domain/support helpers and delete crowded UI logic instead of accepting large tab/view-model files.

### Skill Deepening Focus

1. During refactors, look for changes that delete concepts, branches, or duplicate helpers rather than only moving code between files.
2. Treat ad-hoc special cases in busy flows as design smells; push them into a canonical model, support helper, or focused component.
3. When a change approaches the file-size budget, ask for decomposition before accepting more local code.
4. Route unusually strict maintainability audits to `../thermo-nuclear-code-quality-review/SKILL.md` and keep normal cleanup guidance here.
