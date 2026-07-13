---
name: thermo-nuclear-code-quality-review
description: Default Prisma code review skill. Use for code review, PR audit, thermo-nuclear review, semaforo findings, deep maintainability review, and strict pre-merge quality assessment.
---

# Thermo-Nuclear Code Quality Review

## Role

Own review findings, severity framing, semaforo output, structural
maintainability, and the approval bar for Prisma changes.

## Scope Boundary

Review correctness, safety, privacy, performance, architecture, testability,
failure paths, localization/accessibility, logging, and code structure. Use
`delivery-workflow` for lane selection and gates; use subsystem skills for
specialist implementation rules.

## When to Use

Trigger for code reviews, PR audits, pre-merge audits, strict maintainability
reviews, or any request to find risks before merge.

## Non-negotiable review bar

- Findings lead the response and use Critical/Medium/Low severity.
- Critical and Medium findings block handoff until fixed; Low findings require
  an explicit deferral note.
- Do not approve merely because tests pass: inspect boundaries, failure paths,
  privacy, concurrency, architecture, and maintainability.
- Push for structural simplification, canonical ownership, direct code, and
  decomposition when a change adds spaghetti, wrappers, casts, or file-size
  risk.
- Review artifacts must not contain prompts, transcripts, secrets, or sensitive
  diagnostics.

## Routed references

Read [Thermo review details](references/thermo-review-details.md) for the deep
checklist and examples relevant to the change:

| Request | Reference sections |
|---|---|
| Technical correctness and risk scan | Technical checklist and failure paths |
| Structural/maintainability review | Additional standards, review questions, aggressive flags |
| Finding wording or semaforo output | Output contract and review tone |
| Approval decision | Review workflow and approval bar |

## Output contract

Start with a concise semaforo table when findings exist. Each finding includes
severity, area, file/symbol, issue, impact, and actionable recommendation.
Separate baseline failures from changed-path failures and state assumptions.

## Related Skills

- `../delivery-workflow/SKILL.md`
- `../code-quality/SKILL.md`
- `../testing-xctest/SKILL.md`

## References

- [Detailed thermo review guidance](references/thermo-review-details.md)
