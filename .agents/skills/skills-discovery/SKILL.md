---
name: skills-discovery
description: This skill should be used when the user asks to "find skills", "search the skills registry", "install a skill", or "manage installed skills".
---

# Skills Discovery

Use this skill to discover and optionally install external skills from the `skills.sh` ecosystem.

## When to search for skills

First, check whether an installed local skill already owns the task. Search externally only when:

- The user explicitly asks to find or install a skill.
- The task is specialized and local skills are too generic.
- A mature external skill would materially improve advice quality.

## Discovery workflow

Prefer the `skills.sh` website and the `npx skills` CLI.

```bash
npx skills find <query>
```

Browse popular skills first when the domain is common:

- [skills.sh](https://skills.sh/)
- [skills.sh leaderboard](https://skills.sh/)

Use short, concrete queries:

- Use 1-3 specific terms (too broad = noise, too narrow = misses)
- Prefer widely-used terminology over project-specific jargon
- Technology + task often outperforms either alone
- If results are poor, broaden or try synonyms

## Installation

Determine which client the user is working in before installing. If unclear, ask.

Default client for this repository: `codex`.

```bash
npx skills add <owner/repo@skill>
npx skills add <owner/repo@skill> -g -y
```

## Management

```bash
npx skills check
npx skills update
```

## Presenting results to users

When you find relevant skills:

1. Show 3-5 most relevant results maximum.
2. Include: skill name, what it does, install count, source, and the install command.
3. Evaluate quality using source reputation, installs, recent activity, and fit for the specific task.
4. Always ask for confirmation before installing.
5. Offer direct help if no strong skill exists or the user declines installation.

## Quality Criteria

Prefer skills with:

- Strong adoption
- Recognizable maintainers or organizations
- Recent maintenance activity
- A description that clearly matches the user intent

Be cautious with:

- Low-adoption skills from unknown authors
- Vague descriptions
- Stale repositories
- Skills that overlap heavily with an existing local skill without adding new expertise

## Suggested Reference Skills

These are useful references for Prisma-adjacent work:

- [`openai-docs`](https://skills.sh/openai/skills/openai-docs) for OpenAI product and API documentation
- [`axiom-ios-testing`](https://skills.sh/charleswiltgen/axiom/axiom-ios-testing) as an external testing reference
- [`axiom-ios-accessibility`](https://skills.sh/charleswiltgen/axiom/axiom-ios-accessibility) as an accessibility reference

Do not install these automatically. Use them as references or propose them when the user's task directly matches.

## Related Skills

- `../skill-development/SKILL.md`
