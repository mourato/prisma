---
name: code-quality
description: This skill should be used when the user asks to "improve code readability", "rename for clarity", "refactor duplicated logic", or "apply clean code conventions".
---

# Code Quality Standards

## Role

Use this skill as the canonical owner for language-agnostic readability and everyday maintainability refactoring in Prisma.

- Own naming clarity, decomposition, duplication reduction, and comment quality.
- Push refactors toward fewer concepts, fewer branches, and less incidental machinery.
- Keep code-quality advice independent from language-specific syntax details.
- Delegate Swift-specific idioms and style rules to the Swift conventions owner.

## When to Use

Use this skill when the task is about improving readability, renaming for clarity, refactoring duplicated logic, simplifying implementation structure, or applying clean-code conventions.

## Overview

Practical rules for making implementation code simpler, more direct, and easier to maintain without changing behavior.

## Scope Boundaries

- Use this skill for language-agnostic readability and maintainability principles.
- Use `../swift-conventions/SKILL.md` when the task is specifically about Swift syntax, type-system idioms, or Swift API style.
- Use `../thermo-nuclear-code-quality-review/SKILL.md` for code review or audit mode, especially when approval bars, blockers, severity framing, or structural findings are needed.
- Use `../architecture/SKILL.md` when the question is primarily about module boundaries, dependency direction, or Clean Architecture ownership.

## 1. Refactoring Posture

- **Delete complexity first**: Prefer refactors that remove branches, concepts, helper layers, or duplicated flows over changes that only rearrange them.
- **Reuse -> extend -> create**: Search for existing services, use cases, helpers, and UI support types before adding a new abstraction.
- **Keep behavior stable**: Refactor in small slices and preserve observable behavior unless the user explicitly requested a behavior change.
- **Prefer direct code**: Do not add protocols, wrappers, configuration surfaces, or generic mechanisms unless they reduce real complexity now.
- **Leave fewer concepts behind**: A good refactor should make the next reader hold less state in their head.

## 2. Naming, Comments, and Local Shape

- **Naming clarity**: Name values and functions by intent and domain meaning, not by vague data shape or implementation detail.
- **Focused functions**: Split logic when a function mixes orchestration, policy, formatting, persistence, or UI concerns.
- **Comment restraint**: Explain non-obvious constraints, invariants, and tradeoffs; do not narrate obvious code.
- **Size limits**: For Swift files, use the budgets defined in `../swift-conventions/SKILL.md` (sourced from `.swiftlint.yml`) instead of ad-hoc line limits.

## 3. Structural Smells to Fix

Treat these as refactoring targets, not just style issues:

- Ad-hoc conditionals added to already busy flows.
- One-off booleans, nullable modes, or flags that spread special cases.
- Thin wrappers, identity abstractions, and pass-through helpers that do not clarify ownership.
- Refactors that move code without reducing the number of concepts.
- Copy-pasted logic where a focused helper or canonical service already exists.
- Feature-specific logic leaking into a general-purpose path.
- Silent fallback behavior that hides an unclear invariant.
- Bespoke helpers that duplicate an existing project utility.

## 4. Preferred Moves

- Collapse duplicate branches into one clearer flow.
- Extract a pure helper when it removes real repetition or isolates policy.
- Move logic to the package, service, or type that already owns the concept.
- Replace scattered conditionals with an explicit model, policy, or dispatcher when that reduces complexity.
- Delete wrappers that do not make the API clearer.
- Split large files by owning type directory and unique sibling filenames, following `AGENTS.md`.
- Separate orchestration from business rules when doing so makes each side smaller and easier to test.

## 5. Before Refactoring

Ask:

- What concept, branch, helper, or mode can disappear?
- Is there an existing canonical helper or service?
- Am I creating an abstraction, or removing the need for one?
- Is this logic in the layer that owns the concept?
- Can this be done in a smaller behavior-preserving slice?

## 6. Tooling & Verification

- Keep changes small and atomic to improve review quality.
- Run the scoped checks required by `AGENTS.md` and `../quality-assurance/SKILL.md`.
- Use formatting/linting as verification, not as a substitute for structural simplification.

## Related Skills

- `../swift-conventions/SKILL.md`
- `../thermo-nuclear-code-quality-review/SKILL.md`
- `../architecture/SKILL.md`
- `../quality-assurance/SKILL.md`

## References

- `../swift-conventions/SKILL.md`
- `../thermo-nuclear-code-quality-review/SKILL.md`
- `../architecture/SKILL.md`
- `../quality-assurance/SKILL.md`

## 2026-06-30 Progression Drill

### New Evidence

- `bac49a21` promoted structural simplification, reuse-before-create, file-size discipline, and aggressive complexity deletion into `AGENTS.md`.
- `650cc5d9` added `thermo-nuclear-code-quality-review` as a strict maintainability review mode for abstraction quality, giant files, and spaghetti-condition growth.
- `b953d6ad`, `68dd959f`, and `cdd980f5` showed the preferred pattern: extract domain/support helpers and delete crowded UI logic instead of accepting large tab/view-model files.

### Skill Deepening Focus

1. During refactors, look for changes that delete concepts, branches, or duplicate helpers rather than only moving code between files.
2. Treat ad-hoc special cases in busy flows as design smells; push them into a canonical model, support helper, or focused component.
3. When a change approaches the file-size budget, decompose before accepting more local code.
4. Route review/audit approval bars to `../thermo-nuclear-code-quality-review/SKILL.md`; keep this skill focused on everyday refactoring execution.
