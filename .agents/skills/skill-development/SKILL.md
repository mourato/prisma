---
name: skill-development
description: This skill should be used when the user asks to "create a skill", "refactor SKILL.md", "improve skill trigger descriptions", or "modularize skill resources".
---

# Skill Development

## Role

Use this skill to design, refactor, and validate Agent Skills with clear trigger conditions, minimal overlap, and progressive disclosure.

## Scope Boundary

- Use this skill to author or refactor local skills in this repository.
- Use `../skills-discovery/SKILL.md` when the task is to find or install an external skill.
- Use `../project-standards/SKILL.md` when the task is broader repository policy rather than the structure of a specific skill.

## When to Use

Use this skill when the task requires any of the following:

- Create a new skill folder and initial `SKILL.md`
- Refactor an existing skill with unclear scope or trigger ambiguity
- Split oversized `SKILL.md` files into `references/`, `scripts/`, or `assets/`
- Standardize frontmatter descriptions and cross-skill routing

## Required Workflow

1. Capture concrete usage examples from user intent.
2. Define scope boundaries (`owns`, `delegates`, `does-not-own`).
3. Draft a trigger-focused frontmatter description using exact phrases users would say.
4. Apply progressive disclosure:
   - Keep `SKILL.md` operational and concise.
   - Move detailed references to `references/`.
   - Move deterministic utilities to `scripts/`.
5. Add cross-skill links for all known overlap areas.
6. Validate structure, links, and trigger quality.

## Canonical SKILL.md Template

Prefer this section order unless the skill has a strong reason to differ:

1. `Role`
2. `Scope Boundary`
3. `When to Use`
4. Domain workflow, rules, or routing content
5. `Verification` when the skill has a relevant validation handoff
6. `Related Skills`
7. `References`

For workflow-oriented skills, keep ownership sharp:

- `task-lifecycle` owns risk classification, lane choice, and lifecycle sequencing.
- `quality-assurance` owns concrete command mapping and validation strategy.
- `git-workflow` owns branch, commit, PR, and cleanup mechanics.
- `code-review` owns findings format, severity framing, and review output; every code review includes `thermo-nuclear-code-quality-review` for structural maintainability analysis.
- Router skills should route to these owners rather than restate their rules.

## Skill Quality Checklist

### Frontmatter

- `name` exists and matches folder identity.
- `description` is in third person.
- `description` includes concrete trigger phrases, not generic wording.

### Scope and Routing

- Skill has an explicit scope boundary section.
- Overlapping skills are referenced with clear routing criteria.
- Canonical owner for each domain is explicit.
- Workflow and router skills delegate to the canonical owner instead of duplicating the same policy text.

### Progressive Disclosure

- Main instructions stay focused on execution flow.
- Large examples and long references are moved out of `SKILL.md`.
- Supporting files are discoverable from `SKILL.md` links.

## Validation Commands

Use available tooling and local checks to ensure consistency.

- Ensure each skill directory has `SKILL.md`.
- Validate all relative links from `SKILL.md`.
- Verify no directory is left as an empty placeholder.
- Ensure indexes and routing docs mention only existing skills.
- Run `make guidance-check` after changing `AGENTS.md`, `.agents/`, or command-reference docs.

## Resource Map

- `references/skill-creator-original.md`: full long-form methodology source
- `references/workflows.md`: reusable workflow patterns
- `references/output-patterns.md`: output and structure templates
- `scripts/init_skill.py`: bootstrap new skill structure

## Related Skills

- `../skills-discovery/SKILL.md`

## 2026-06-30 Progression Drill

### New Evidence

- `650cc5d9` added `thermo-nuclear-code-quality-review` with `disable-model-invocation: true`, creating a specialized review skill rather than overloading the normal `code-quality` owner.
- `bac49a21` updated `AGENTS.md` with stricter structural-review standards, so skill changes must preserve policy ownership instead of duplicating the same rules everywhere.
- Recent `.agents` history shows `make guidance-check` remains the required validator after editing skills, indexes, routing docs, or `AGENTS.md`.

### Skill Deepening Focus

1. When adding a sharper specialist skill, define which normal skill invokes it and which output contract remains elsewhere.
2. Keep strict review prompts specialized; route to them instead of copying their full severity language into broad code-quality or project-standard skills.
3. Validate new frontmatter fields and routing coverage with `make guidance-check`.
4. After adding or renaming a skill, check `skills-lock.json`, `.agents/SKILLS_INDEX.md`, taxonomy, and routing docs for drift.
