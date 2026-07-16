# Plan 029: Make thermo-nuclear review the default code-review skill

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report; do not improvise. When done, update the status row for this plan in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 67f9efe7..HEAD -- .agents/skills/code-review .agents/skills/thermo-nuclear-code-quality-review .agents/skills/code-quality/SKILL.md .agents/skills/task-lifecycle/SKILL.md .agents/skills/quality-assurance/SKILL.md .agents/skills/git-workflow/SKILL.md .agents/skills/project-standards/SKILL.md .agents/skills/benchmarking/SKILL.md .agents/skills/SKILLS_TAXONOMY.md .agents/SKILLS_INDEX.md .agents/docs/skill-routing.md AGENTS.md plans/README.md`
>
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live files before proceeding. If
> `code-review` has already been removed or `thermo-nuclear-code-quality-review`
> has already become the default review owner, treat that as drift and reconcile
> carefully before editing.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `67f9efe7`, 2026-07-10

## Why this matters

Prisma currently routes normal code-review requests through `code-review`, then
requires `thermo-nuclear-code-quality-review` as a structural sub-pass. That
keeps the stronger review voice and approval bar behind a wrapper skill. The
desired end state is simpler: normal "code review", PR audit, and pre-merge
review requests should route directly to `thermo-nuclear-code-quality-review`,
and that skill should own both the strict structural depth and the useful output
contract that currently lives in `code-review`.

This reduces one skill, removes a routing hop, and makes the review tone match
the stricter standard by default.

## Current state

Relevant files and roles:

- `.agents/skills/code-review/SKILL.md` - current default review skill; owns
  findings format, severity language, review focus, and semaforo output.
- `.agents/skills/thermo-nuclear-code-quality-review/SKILL.md` - stricter
  maintainability review skill; currently says it does not own semaforo
  formatting and should be used inside `code-review`.
- `.agents/SKILLS_INDEX.md`, `.agents/skills/SKILLS_TAXONOMY.md`, and
  `.agents/docs/skill-routing.md` - registries and routing docs.
- `AGENTS.md` - requires a Full-lane semaforo review with a mandatory
  thermo-nuclear structural pass.
- `.agents/skills/task-lifecycle/SKILL.md`,
  `.agents/skills/quality-assurance/SKILL.md`,
  `.agents/skills/git-workflow/SKILL.md`,
  `.agents/skills/project-standards/SKILL.md`,
  `.agents/skills/code-quality/SKILL.md`, and
  `.agents/skills/benchmarking/SKILL.md` - adjacent references to review
  ownership.

Current `code-review` excerpts to migrate:

```text
.agents/skills/code-review/SKILL.md:10-15
Use this skill as the canonical owner for local review depth, findings format, and semáforo output in Prisma.
- Own review framing, severity language, and output expectations.
- Focus on correctness, regression risk, safety, and missing verification.
- Always include the structural maintainability pass from `../thermo-nuclear-code-quality-review/SKILL.md`.
- Delegate lane policy and command selection to their specialist owners.
```

```text
.agents/skills/code-review/SKILL.md:30-37
Perform a pragmatic review of the change set before the final push, focusing on:
- Correctness and concurrency (Swift 6 / `@MainActor` / race conditions)
- Security and privacy (sensitive data, logs, permissions)
- Performance (hot paths, allocations, observation/Combine)
- UX (Settings consistency, invalid states, feedback)
- Maintainability (duplication, cohesion, coupling, naming)
- Testability (injection points, pure logic)
```

```text
.agents/skills/code-review/SKILL.md:43-86
### 1) Scope
- List commits and touched files.
- Separate behavior changes from structural refactors.
### 2) Technical checklist
- Threading...
- Side effects...
- State...
- Failure paths...
- Logs...
- i18n/a11y...
### 6) Final summary table (traffic-light)
Use a short table with priority and recommendation:
- Critical: crash risk, data loss, security, user harm
- Medium: confusing behavior, technical debt, performance regressions
- Low: clarity improvements, optional refactors
Suggested columns:
- Severity
- Area (UX/Perf/Sec/Conc/Test/Arch)
- Finding
- Impact
- Recommendation
```

Current thermo excerpts to update:

```text
.agents/skills/thermo-nuclear-code-quality-review/SKILL.md:13-18
- This skill owns unusually strict code-quality review prompts and approval bars.
- This skill is the mandatory structural maintainability pass for every `../code-review/SKILL.md` review.
- It does not replace `../code-quality/SKILL.md` for everyday readability/refactoring guidance.
- It does not own semáforo review formatting; use `../code-review/SKILL.md` for the final findings format and severity framing.
```

```text
.agents/skills/thermo-nuclear-code-quality-review/SKILL.md:171-184
## Output Expectations
Prioritize findings in this order:
1. Structural code-quality regressions
...
Do not flood the review with low-value nits if there are larger structural issues.
Prefer a smaller number of high-conviction comments over a long list of cosmetic notes.
```

Current routing excerpts to update:

```text
.agents/SKILLS_INDEX.md:14
| `code-review` | `.agents/skills/code-review/` | Review changes, do semáforo review (🔴/🟡/🟢), audit PRs, find risks before merge; always includes thermo-nuclear structural analysis |
```

```text
.agents/SKILLS_INDEX.md:95
- `code-review`: findings format, severity framing, semáforo review output; always includes `thermo-nuclear-code-quality-review` for structural code analysis
```

Repository conventions that apply:

- Documentation must be in English.
- Keep `.agents/skills`, `.agents/SKILLS_INDEX.md`,
  `.agents/skills/SKILLS_TAXONOMY.md`, `.agents/docs/skill-routing.md`, and
  `AGENTS.md` synchronized in the same pass.
- After changing `.agents` guidance, run `make guidance-check`.
- Use Conventional Commits.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Find old review routing | `rg -n "code-review|thermo-nuclear-code-quality-review|semáforo|semaforo" .agents AGENTS.md plans/README.md` | Shows references to migrate before edits; after edits, `code-review` appears only in historical plans or explicit migration notes |
| Guidance validation | `make guidance-check` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |
| Skill count | `find .agents/skills -maxdepth 2 -name SKILL.md -print \| wc -l` | One fewer than before this plan |

## Suggested executor toolkit

- Use `project-standards` for skill registry and routing updates.
- Use `documentation` only for wording polish.
- Do not use `code-review` as an active skill after this plan begins; it is
  being absorbed into `thermo-nuclear-code-quality-review`.

## Scope

**In scope**:

- `.agents/skills/thermo-nuclear-code-quality-review/SKILL.md`
- `.agents/skills/code-review/` (delete after migration)
- `.agents/skills/code-quality/SKILL.md`
- `.agents/skills/task-lifecycle/SKILL.md`
- `.agents/skills/quality-assurance/SKILL.md`
- `.agents/skills/git-workflow/SKILL.md`
- `.agents/skills/project-standards/SKILL.md`
- `.agents/skills/benchmarking/SKILL.md`
- `.agents/skills/SKILLS_TAXONOMY.md`
- `.agents/SKILLS_INDEX.md`
- `.agents/docs/skill-routing.md`
- `AGENTS.md`
- `plans/README.md`

**Out of scope**:

- Swift source, tests, localization files, Xcode project files, Makefile,
  scripts, CI config, and release files.
- Renaming `thermo-nuclear-code-quality-review`; keep the name.
- Weakening the thermo review standard.
- Changing risk-lane policy, quality gate commands, or Git mechanics.
- Merging `code-quality` into thermo. `code-quality` remains everyday
  refactoring guidance; thermo remains review/audit mode.

## Git workflow

- Branch: work directly on `main` because the operator explicitly requested the
  whole cleanup on `main`.
- Commit message: `docs(agents): make thermo review the default`
- Do not push until `make guidance-check` and `git diff --check` pass.

## Steps

### Step 1: Make thermo the default review skill

Edit `.agents/skills/thermo-nuclear-code-quality-review/SKILL.md`.

Required changes:

- Update frontmatter description so it triggers for ordinary review requests:
  "review this change", "do a code review", "audit this PR", "find risks
  before merge", "thermo-nuclear review", and similar.
- Remove `disable-model-invocation: true` so the skill can be used directly as
  the default review skill.
- Update Role to say this skill owns Prisma code review by default: strict
  structural maintainability, correctness/regression review, findings format,
  severity framing, and approval bar.
- Update Scope Boundary:
  - Keep `code-quality` as everyday refactoring guidance.
  - Keep `task-lifecycle` for when review happens and lane depth.
  - Keep `quality-assurance` for validation commands and merge gates.
  - Use subsystem skills for domain-specific details.
  - Remove statements saying thermo does not own semaforo formatting.
- Update When to Use so any code review/audit/pre-merge review request routes
  here.

**Verify**:

```bash
rg -n "disable-model-invocation|does not own sem|code-review/SKILL|whenever `../code-review" .agents/skills/thermo-nuclear-code-quality-review/SKILL.md
```

Expected: no matches.

### Step 2: Merge the useful code-review checklist into thermo

In `.agents/skills/thermo-nuclear-code-quality-review/SKILL.md`, add or update
sections so the skill owns the full review contract:

- `Review Scope`
  - list commits and touched files
  - separate behavior changes from structural refactors
- `Technical Checklist`
  - correctness and concurrency
  - security/privacy
  - performance
  - UX/product behavior
  - testability
  - state/failure paths
  - logs/no PII
  - i18n/a11y when relevant
- `Output Contract`
  - findings first
  - each finding includes severity, area, file/symbol reference, impact, and
    recommendation
  - use traffic-light/semaforo severities:
    - Critical: crash risk, data loss, security, user harm, hard-constraint
      breach, or structural regression that blocks merge
    - Medium: confusing behavior, maintainability debt, performance regression,
      missing tests, or should-fix-before-merge issue
    - Low: optional clarity/style/refactor note
  - include open questions/assumptions after findings
  - keep summary brief and secondary
- `Review Workflow`
  - inspect commits/touched files
  - run strict thermo pass
  - run technical/product/safety checklist
  - check verification evidence
  - produce semaforo output
  - fix all Critical and Medium findings before merge when the operator asks
    the reviewer to remediate findings

Keep the existing strict tone, non-negotiable standards, primary questions,
preferred remedies, and approval bar. Do not soften them.

**Verify**:

```bash
rg -n "Review Scope|Technical Checklist|Output Contract|Critical|Medium|Low|Approval Bar" .agents/skills/thermo-nuclear-code-quality-review/SKILL.md
```

Expected: all terms appear.

### Step 3: Remove the old wrapper skill

Delete `.agents/skills/code-review/` after its useful content has been
migrated.

**Verify**:

```bash
test ! -e .agents/skills/code-review
test -f .agents/skills/thermo-nuclear-code-quality-review/SKILL.md
```

Expected: both commands exit 0.

### Step 4: Update registries and routing docs

Update `.agents/SKILLS_INDEX.md`:

- Remove the `code-review` row.
- Change `thermo-nuclear-code-quality-review` row to say it is the default for
  code review, PR audits, findings before merge, strict maintainability, and
  semaforo output.
- Under Code Quality, replace `Code review: code-review` with
  `Code review: thermo-nuclear-code-quality-review`.
- Under Engineering Workflow Ownership, remove the `code-review` owner line and
  make `thermo-nuclear-code-quality-review` own review findings, severity,
  semaforo output, and strict structural review.
- Under Skill Dependencies, remove `code-review -> ...`; add
  `thermo-nuclear-code-quality-review -> task-lifecycle / quality-assurance /
  subsystem skills` as specialist dependencies.

Update `.agents/skills/SKILLS_TAXONOMY.md`:

- Remove the `code-review` row.
- Change thermo owner from Specialist to Canonical.
- Update thermo scope/action to say it is the default code-review owner.
- Remove `code-review` from task-lifecycle overlap and grouping summary.

Update `.agents/docs/skill-routing.md`:

- In Code Quality and Refactoring, replace the sentence that tells agents to use
  `code-review` with a sentence pointing to
  `thermo-nuclear-code-quality-review`.
- In the direct access table, remove `code-review`.
- Ensure the thermo row describes default code review, PR audits, semaforo
  output, and strict maintainability.

**Verify**:

```bash
rg -n "code-review" .agents/SKILLS_INDEX.md .agents/skills/SKILLS_TAXONOMY.md .agents/docs/skill-routing.md
```

Expected: no matches.

### Step 5: Update adjacent skill references

Update these files:

- `.agents/skills/code-quality/SKILL.md`: route review/audit approval bars to
  `thermo-nuclear-code-quality-review`; remove `code-review` related links.
- `.agents/skills/task-lifecycle/SKILL.md`: use thermo for review findings and
  semaforo review; keep task-lifecycle as risk/lane owner.
- `.agents/skills/quality-assurance/SKILL.md`: related skill points to thermo
  for review output formatting/findings.
- `.agents/skills/git-workflow/SKILL.md`: review findings use thermo; keep Git
  mechanics separate.
- `.agents/skills/project-standards/SKILL.md`: workflow ownership split says
  thermo owns review findings, severity framing, semaforo output, and strict
  structural pass.
- `.agents/skills/benchmarking/SKILL.md`: review changes inspired by references
  through thermo.
- `AGENTS.md`: Full lane review language should say thermo-nuclear semaforo
  review is the code-review gate, not "code-review plus thermo pass".

**Verify**:

```bash
rg -n "code-review" .agents AGENTS.md
```

Expected: no operational references. Historical mentions inside old plans are
allowed only if the command searches `plans/`.

### Step 6: Validate guidance and update plan status

Run:

```bash
make guidance-check
git diff --check
find .agents/skills -maxdepth 2 -name SKILL.md -print | sort | wc -l
```

Expected:

- `make guidance-check` exits 0.
- `git diff --check` exits 0.
- skill count is one fewer than before this plan.

Update `plans/README.md` status row for plan 029 to `DONE`.

## Test plan

This is guidance-only work. No Swift tests are required.

Required verification:

- `make guidance-check` exits 0.
- `git diff --check` exits 0.
- `rg -n "code-review" .agents AGENTS.md` returns no operational references.
- `test ! -e .agents/skills/code-review` exits 0.
- `find .agents/skills -maxdepth 2 -name SKILL.md -print | sort | wc -l`
  shows one fewer skill than before this plan.

## Done criteria

All must hold:

- [ ] `thermo-nuclear-code-quality-review` frontmatter triggers normal code
      review requests.
- [ ] `thermo-nuclear-code-quality-review` owns review findings format,
      severity framing, semaforo output, technical checklist, and strict
      structural maintainability.
- [ ] `disable-model-invocation: true` is removed from thermo.
- [ ] `.agents/skills/code-review/` no longer exists.
- [ ] `.agents/SKILLS_INDEX.md`, `.agents/skills/SKILLS_TAXONOMY.md`,
      `.agents/docs/skill-routing.md`, `AGENTS.md`, and adjacent skills point
      normal review routing to thermo.
- [ ] `code-quality` remains separate for everyday refactoring guidance.
- [ ] `task-lifecycle` remains separate for risk/lane sequencing.
- [ ] `quality-assurance` remains separate for validation command mapping.
- [ ] `make guidance-check` exits 0.
- [ ] `git diff --check` exits 0.
- [ ] `plans/README.md` status row for plan 029 is updated.

## STOP conditions

Stop and report back instead of improvising if:

- `make guidance-check` requires a skill literally named `code-review`.
- Another tool outside `.agents` loads `.agents/skills/code-review/SKILL.md`
  by hardcoded path.
- Removing `disable-model-invocation: true` breaks skill validation.
- You find a separate registry or taxonomy file not listed in this plan that
  still requires `code-review`.
- The migration appears to require changing source code, Makefile, scripts,
  tests, or CI config.

## Maintenance notes

- Future review guidance should be added to
  `thermo-nuclear-code-quality-review` first.
- Keep `code-quality` focused on behavior-preserving simplification during
  implementation, not review verdicts.
- Keep `task-lifecycle` focused on when review happens and what lane requires
  it, not on findings format.
- Keep `quality-assurance` focused on commands and gates, not review tone.
