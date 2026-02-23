---
name: skill-development
description: This skill should be used when the user asks to "create a skill", "refactor SKILL.md", "improve skill trigger descriptions", or "modularize skill resources".
---

# Skill Development

## Role

Use this skill to design, refactor, and validate Agent Skills with clear trigger conditions, minimal overlap, and progressive disclosure.

## When to Use

Use this skill when the task requires any of the following:

- Create a new skill folder and initial `SKILL.md`
- Refactor an existing skill with unclear scope or trigger ambiguity
- Split oversized `SKILL.md` files into `references/`, `scripts/`, or `assets/`
- Standardize frontmatter descriptions and cross-skill routing

If the request is to find or install external skills from a registry, use `../skills-discovery/SKILL.md`.

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

## Skill Quality Checklist

### Frontmatter

- `name` exists and matches folder identity.
- `description` is in third person.
- `description` includes concrete trigger phrases, not generic wording.

### Scope and Routing

- Skill has an explicit scope boundary section.
- Overlapping skills are referenced with clear routing criteria.
- Canonical owner for each domain is explicit.

### Progressive Disclosure

- Main instructions stay focused on execution flow.
- Large examples and long references are moved out of `SKILL.md`.
- Supporting files are discoverable from `SKILL.md` links.

## Validation Commands

Use available tooling and local checks to ensure consistency.

- Ensure each skill directory has `SKILL.md`.
- Validate all relative links from `SKILL.md`.
- Verify no directory is left as an empty placeholder.

## Resource Map

- `references/skill-creator-original.md`: full long-form methodology source
- `references/workflows.md`: reusable workflow patterns
- `references/output-patterns.md`: output and structure templates
- `scripts/init_skill.py`: bootstrap new skill structure

## Related Skills

- `../skills-discovery/SKILL.md`
