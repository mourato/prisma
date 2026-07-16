# Plan 028: Consolidate macOS UI guidance into one primary skill

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report; do not improvise. When done, update the status row for this plan in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat e80faf04..HEAD -- .agents/skills/native-app-designer .agents/skills/swiftui-patterns .agents/skills/macos-development .agents/skills/preview-coverage .agents/skills/macos-app-engineering .agents/skills/accessibility-audit .agents/skills/localization .agents/skills/menubar .agents/skills/code-quality .agents/skills/swift-conventions .agents/skills/SKILLS_TAXONOMY.md .agents/SKILLS_INDEX.md .agents/docs/skill-routing.md AGENTS.md README.md`
>
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live files before proceeding. If the
> ownership model has already been consolidated or the target skill names no
> longer exist, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `e80faf04`, 2026-07-10

## Why this matters

Prisma currently has four UI/macOS guidance skills that must be chained for
ordinary Apple-platform UI work: `native-app-designer`, `swiftui-patterns`,
`macos-development`, and `preview-coverage`. Their stated boundaries are
reasonable, but the content now overlaps across UX criteria, SwiftUI
composition, motion rules, design-system usage, Settings-specific rules,
AppKit bridging, preview requirements, accessibility reminders, and validation
commands. A weaker executor is likely to miss one of the required pairings or
apply the same rule twice from different skills.

This plan consolidates those four skills into one primary skill,
`macos-app-engineering`, while keeping true specialists separate:
`accessibility-audit`, `localization`, `menubar`, `code-quality`,
`swift-conventions`, `code-review`, and `thermo-nuclear-code-quality-review`.
The goal is fewer top-level skills with clearer ownership, not a loss of
quality gates.

## Current state

Relevant files and roles:

- `.agents/skills/native-app-designer/SKILL.md` - primary UX/UI direction, but
  also includes Settings component rules and AppKit bridging guidance.
- `.agents/skills/swiftui-patterns/SKILL.md` - SwiftUI composition/state/layout,
  but also includes UX checklist items, motion rules, design-system policy,
  Settings component rules, and preview requirements.
- `.agents/skills/macos-development/SKILL.md` - platform lifecycle and AppKit
  integration, but also repeats native interaction, accessibility, workflow,
  and command guidance.
- `.agents/skills/preview-coverage/SKILL.md` - preview-specific requirements
  that are small enough to live inside the consolidated macOS/UI skill.
- `.agents/skills/accessibility-audit/SKILL.md`, `.agents/skills/localization/SKILL.md`,
  and `.agents/skills/menubar/SKILL.md` - specialist skills that should remain
  separate.
- `.agents/skills/code-quality/SKILL.md` and `.agents/skills/swift-conventions/SKILL.md`
  - currently have a clean split and should not be merged in this plan.
- `.agents/SKILLS_INDEX.md` and `.agents/docs/skill-routing.md` - registries
  that must be synchronized with any skill rename/delete.
- `.agents/skills/SKILLS_TAXONOMY.md` - taxonomy registry that must stay
  synchronized with the index and routing docs.

Current overlap excerpts:

```text
.agents/skills/native-app-designer/SKILL.md:22-26
- This skill owns visual/interaction direction and UX quality criteria.
- This skill complements implementation-oriented skills:
  - `../swiftui-patterns/SKILL.md` for SwiftUI composition/state/layout
  - `../macos-development/SKILL.md` for platform integration and lifecycle
  - `../debugging-strategies/SKILL.md` for runtime diagnosis when UX symptoms need investigation
```

```text
.agents/skills/native-app-designer/SKILL.md:56-63
- In settings screens, use `SettingsListGroup` for simple lists of rows so spacing and separators stay native and consistent. Use `DSGroup` only for composed content such as editors, tables, cards, app/model pickers, or callout/action clusters.
- In deferred-save forms or sheets, prefer checkbox-style boolean controls over switch controls.
- Treat popovers/help affordances as escalation, not baseline content.
- Use motion to guide attention and communicate state changes.
- Keep reduced-motion behavior available for motion-heavy transitions.
- Keep motion local and purposeful; do not introduce shader/matched-geometry machinery unless a Prisma surface clearly earns it and the reduced-motion fallback is clear.
- For macOS surfaces, use AppKit bridging only when SwiftUI behavior is insufficient.
```

```text
.agents/skills/swiftui-patterns/SKILL.md:10-20
Use this skill as the canonical owner for SwiftUI composition, state handling, and layout patterns in Prisma.
- Own view composition, navigation, state wrappers, and reusable UI-block guidance.
- Keep SwiftUI implementation advice aligned with design-system reuse, preview expectations, motion restraint, and performance hygiene.
- Delegate UX direction to `native-app-designer` and unknown-root-cause runtime investigation to `debugging-strategies`.
```

```text
.agents/skills/swiftui-patterns/SKILL.md:173-190
## Settings UI Patterns
### Settings UX Consistency Checklist
- Use drill-down rows consistently for secondary settings pages.
- For any settings row that pushes a secondary page from a `NavigationStack`, reuse `SettingsDrillDownListRow`.
- Avoid repeating the same title or description in the page header and again in the first settings card unless the card introduces materially new context.
- Ensure keyboard navigation works (Tab/Arrow/Enter/Escape) across rows and detail pages.
- Pair row title/description semantics for VoiceOver and include clear accessibility hints.
```

```text
.agents/skills/macos-development/SKILL.md:14-20
- This skill owns implementation guidance for platform lifecycle, architecture usage, UI integration, and system APIs.
- This skill does not replace specialist skills:
  - `native-app-designer` for primary UI/UX direction and experience analysis
  - `quality-assurance` for verification lanes and merge gates
  - `swift-concurrency-expert` for Swift 6.2 diagnostics/remediation
  - `swiftui-patterns` for SwiftUI composition, motion implementation, and performance hygiene
```

```text
.agents/skills/preview-coverage/SKILL.md:34-59
1. Every `struct ...: View` must include at least one `#Preview`.
2. Prefer multiple previews for meaningful states.
3. Avoid side effects in previews.
4. If a view triggers startup work, gate it for previews using `PreviewRuntime.isRunning`.
5. If bindings are needed, use local preview state wrappers.
6. For AppKit controllers, preview the underlying SwiftUI rendering surface.
7. Verify keyboard/focus behavior for settings and drill-down surfaces when previews include interactive controls.
...
make preview-check
```

Specialist boundaries to preserve:

```text
.agents/skills/accessibility-audit/SKILL.md:10-14
Use this skill for accessibility-sensitive interaction work in Prisma.
- Own accessibility audits across SwiftUI and AppKit surfaces.
- Cover keyboard navigation, focus order, reduced motion, non-color cues, overlays, and panel behavior.
- Delegate localization and accessible copy keys to `../localization/SKILL.md`.
```

```text
.agents/skills/code-quality/SKILL.md:10-15
Use this skill as the canonical owner for language-agnostic readability and everyday maintainability refactoring in Prisma.
- Own naming clarity, decomposition, duplication reduction, and comment quality.
- Push refactors toward fewer concepts, fewer branches, and less incidental machinery.
- Keep code-quality advice independent from language-specific syntax details.
- Delegate Swift-specific idioms and style rules to the Swift conventions owner.
```

```text
.agents/skills/swift-conventions/SKILL.md:10-14
Use this skill as the canonical owner for Swift-specific style, naming, type-safety, and module-organization guidance in Prisma.
- Own Swift-language idioms and lint-aligned writing rules.
- Keep Swift conventions aligned with `.swiftlint.yml` and repository module structure.
- Delegate language-agnostic readability advice to the code-quality owner.
```

Repository conventions that apply:

- Documentation must be written in English.
- Keep `.agents/skills`, `.agents/SKILLS_INDEX.md`, `.agents/docs/skill-routing.md`,
  and `AGENTS.md` synchronized when skill ownership changes.
- After changing `.agents/` guidance, run `make guidance-check`.
- Do not create a root-level `docs/` folder.
- Use the skill section order from `project-standards`: `Role`, `Scope Boundary`,
  `When to Use`, domain-specific workflow/guidance, `Verification` when
  relevant, `Related Skills`, and `References`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Find references | `rg -n "native-app-designer|swiftui-patterns|macos-development|preview-coverage|macos-app-engineering" .agents AGENTS.md README.md plans` | Shows only expected old references before edits; after edits, old names appear only in this plan and historical completed plans unless intentionally retained as migration notes |
| Guidance validation | `make guidance-check` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0, no whitespace errors |
| Scope check | `git status --short` | Only in-scope files changed |

## Suggested executor toolkit

- Use `project-standards` when editing `.agents` guidance and registries.
- Use `documentation` if available for wording cleanup only; do not turn this
  into broad documentation rewriting.
- Do not use `native-app-designer`, `swiftui-patterns`, `macos-development`, or
  `preview-coverage` as independent routing authorities once the new skill is
  created; their content is being consolidated.

## Scope

**In scope** (the only paths you should modify):

- `.agents/skills/macos-app-engineering/SKILL.md` (create)
- `.agents/skills/native-app-designer/` (delete after migration)
- `.agents/skills/swiftui-patterns/` (delete after migration)
- `.agents/skills/macos-development/` (delete after migration)
- `.agents/skills/preview-coverage/` (delete after migration)
- `.agents/skills/accessibility-audit/SKILL.md` (update related-skill references only)
- `.agents/skills/localization/SKILL.md` (update related-skill references only)
- `.agents/skills/menubar/SKILL.md` (update related-skill references only)
- `.agents/skills/code-quality/SKILL.md` (only if needed to say code-quality remains separate; no content merge)
- `.agents/skills/swift-conventions/SKILL.md` (only if needed to say Swift conventions remains separate; no content merge)
- `.agents/skills/SKILLS_TAXONOMY.md`
- `.agents/SKILLS_INDEX.md`
- `.agents/docs/skill-routing.md`
- `AGENTS.md` (only if it references deleted skill names or needs the new canonical skill mentioned)
- `README.md` (only if it references deleted skill names)
- `plans/README.md` (status update only)

**Out of scope** (do NOT touch):

- App, package, Swift source, tests, localization strings, Xcode project files,
  Makefile, scripts, or CI config.
- `accessibility-audit`, `localization`, `menubar`, `code-quality`,
  `swift-conventions`, `code-review`, `thermo-nuclear-code-quality-review`,
  `quality-assurance`, and `task-lifecycle` as standalone skills. Keep them.
- Any root-level `docs/` folder or new markdown backlog.
- A second consolidation that merges `code-quality` and `swift-conventions`.
  That can be a future plan if wanted, but not this one.

## Git workflow

- Branch: `advisor/028-consolidate-macos-ui-guidance-skills`
- Commit message: `docs(agents): consolidate macOS UI guidance skills`
- Do not push or open a PR unless the operator explicitly asks.

## Steps

### Step 1: Confirm the stale-reference inventory

Run:

```bash
rg -n "native-app-designer|swiftui-patterns|macos-development|preview-coverage" .agents AGENTS.md README.md
```

Save the result mentally as the migration checklist. You must update every
current operational reference. Historical references under `plans/` can remain
because they describe completed work.

**Verify**: the command exits 0 and shows references in `.agents/skills`,
`.agents/SKILLS_INDEX.md`, `.agents/docs/skill-routing.md`, and possibly
`AGENTS.md` or `README.md`.

### Step 2: Create the consolidated skill

Create `.agents/skills/macos-app-engineering/SKILL.md`.

Use this frontmatter:

```markdown
---
name: macos-app-engineering
description: Use for macOS UI/app work that touches SwiftUI views, AppKit bridging, Settings UI, design-system components, interface direction, preview coverage, or platform lifecycle.
---
```

Use this top-level structure:

```markdown
# macOS App Engineering

## Role
## Scope Boundary
## When to Use
## Execution Sequence
## UI/UX Direction
## SwiftUI Composition and State
## Settings and Design System Patterns
## Motion, Performance, and Rendering
## macOS Platform Integration
## Preview Requirements
## Verification
## Related Skills
## References
## Historical Progression Notes
```

Content requirements:

- Start with a clear statement that this is the single primary skill for
  ordinary macOS UI/app implementation in Prisma.
- Inline the UX acceptance criteria from `native-app-designer`, but keep them
  concise: clarity, consistency, native feel, accessibility awareness, purposeful
  motion, visual rhythm, and redundancy control.
- Inline the SwiftUI implementation rules from `swiftui-patterns`: state
  ownership, navigation, cheap deterministic computed view state, stable row
  identity, extracting complex repeated row bodies, and using existing
  design-system blocks before creating new wrappers.
- Inline the canonical Settings rules from `swiftui-patterns` and
  `native-app-designer`: `SettingsListGroup` for plain settings lists,
  `DSGroup` for composed content, no `Divider()` inside `SettingsListGroup`,
  no local `.settingsListRow()`, `SettingsDrillDownListRow` and
  `SettingsListDrillDownButtonRow` for push-style rows, native menu pickers for
  ordinary settings values, checkbox-style toggles for deferred-save forms,
  switches for immediate settings, no redundant helper copy/popovers.
- Inline the macOS lifecycle/AppKit rules from `macos-development`: AppKit
  bridging only when SwiftUI is insufficient, observers/taps/monitors released
  deterministically, `@MainActor` for UI-bound state, avoid blocking async
  paths, status item/hotkeys registered once, settings open/close does not
  duplicate observers.
- Inline the preview rules from `preview-coverage`: every SwiftUI `View` gets at
  least one `#Preview`, meaningful state variants get multiple previews,
  previews are deterministic and side-effect free, use `PreviewRuntime.isRunning`
  and `PreviewStateContainer` when needed, verify with `make preview-check`.
- Route specialists instead of absorbing them:
  - `accessibility-audit` for VoiceOver, focus order, keyboard-only navigation,
    reduced-motion audits, non-color signals, overlays, and panel behavior.
  - `localization` for `.localized`, locale-file symmetry, and accessible copy
    keys.
  - `menubar` for `NSStatusItem`, `NSMenu`, `NSPopover`, and non-activating
    floating panels.
  - `debugging-strategies` for unclear jank, layout thrash, crashes, or flaky
    runtime behavior.
  - `swift-concurrency-expert` for actor-isolation/Sendable compiler errors.
  - `quality-assurance` for validation lane policy.
  - `code-quality` and `swift-conventions` for general refactoring and Swift
    syntax/type-system rules.
- Do not copy the long illustrative code samples from old skills unless they
  are still essential. Prefer concise rules and one or two short examples for
  Settings list groups and checkbox-vs-switch behavior.
- Preserve the high-value progression notes, but compress them into a
  "Historical Progression Notes" section. Keep the substance, not every commit
  hash.

**Verify**:

```bash
test -f .agents/skills/macos-app-engineering/SKILL.md
rg -n "swiftui-patterns|native-app-designer|macos-development|preview-coverage" .agents/skills/macos-app-engineering/SKILL.md
```

Expected: first command exits 0. Second command may show old names only in a
short migration note or "replaces" sentence; it must not tell future agents to
load those old skills.

### Step 3: Remove the replaced skill directories

Delete these directories after their useful content has been migrated:

```text
.agents/skills/native-app-designer/
.agents/skills/swiftui-patterns/
.agents/skills/macos-development/
.agents/skills/preview-coverage/
```

Do not delete or edit unrelated skills.

**Verify**:

```bash
test ! -e .agents/skills/native-app-designer
test ! -e .agents/skills/swiftui-patterns
test ! -e .agents/skills/macos-development
test ! -e .agents/skills/preview-coverage
test -e .agents/skills/accessibility-audit/SKILL.md
test -e .agents/skills/localization/SKILL.md
test -e .agents/skills/menubar/SKILL.md
```

Expected: all commands exit 0.

### Step 4: Update the skill registry, taxonomy, and routing docs

Update `.agents/SKILLS_INDEX.md`:

- Replace the four rows for `native-app-designer`, `swiftui-patterns`,
  `macos-development`, and `preview-coverage` with one row for
  `macos-app-engineering`.
- Update "UI/UX and Interfaces" so it starts with `macos-app-engineering`, then
  escalates to `accessibility-audit`, `localization`, `menubar`,
  `debugging-strategies`, or `swift-concurrency-expert` when needed.
- Update "Performance Issues" so SwiftUI rendering starts with
  `macos-app-engineering`, then `debugging-strategies` if root cause is unclear.
- Update "Platform-Specific (macOS)" so general macOS UI/app guidance is
  `macos-app-engineering`; keep `menubar` for menu bar UI.
- Update "Skill Dependencies" so old `swiftui-patterns -> native-app-designer`
  is removed. Add `macos-app-engineering -> accessibility-audit/localization/menubar`
  only as specialist escalation, not mandatory chaining.

Update `.agents/skills/SKILLS_TAXONOMY.md`:

- Remove rows for the four replaced skills.
- Add one row for `macos-app-engineering`.
- Update overlap/dependency references from the old names to
  `macos-app-engineering`.
- Update grouping summaries so macOS/UI lists include
  `macos-app-engineering`, `menubar`, and `accessibility-audit` rather than the
  deleted skills.

Update `.agents/docs/skill-routing.md`:

- Replace the general priority entries for `macos-development` and
  `native-app-designer` with `macos-app-engineering`.
- Collapse "UI/UX and Interaction Work", "SwiftUI Performance Issues", and
  "Menu Bar and macOS Native UI" wording so ordinary macOS UI/app work routes
  to `macos-app-engineering`.
- Keep `menubar` primary only when the work is specifically `NSStatusItem`,
  `NSMenu`, `NSPopover`, or non-activating panel behavior.
- Keep `accessibility-audit`, `localization`, `code-quality`,
  `swift-conventions`, `quality-assurance`, and `task-lifecycle` boundaries
  unchanged.

**Verify**:

```bash
rg -n "native-app-designer|swiftui-patterns|macos-development|preview-coverage" .agents/SKILLS_INDEX.md .agents/skills/SKILLS_TAXONOMY.md .agents/docs/skill-routing.md
```

Expected: no matches.

### Step 5: Update adjacent skill cross-references

Update related-skill references in adjacent skills:

- `.agents/skills/accessibility-audit/SKILL.md`: replace
  `../native-app-designer/SKILL.md` with
  `../macos-app-engineering/SKILL.md`; remove the duplicate `menubar` entry if
  still present.
- `.agents/skills/localization/SKILL.md`: replace
  `../swiftui-patterns/SKILL.md` with `../macos-app-engineering/SKILL.md`.
- `.agents/skills/menubar/SKILL.md`: replace broad UI/UX and platform guidance
  references with `../macos-app-engineering/SKILL.md`.
- `.agents/skills/code-quality/SKILL.md` and
  `.agents/skills/swift-conventions/SKILL.md`: do not merge them; only add a
  short related-skill reference to `macos-app-engineering` if it helps clarify
  that UI composition belongs there, not in code-quality.

Search all `.agents/skills` for old names and update or remove stale links.

**Verify**:

```bash
rg -n "native-app-designer|swiftui-patterns|macos-development|preview-coverage" .agents/skills
```

Expected: no matches, except inside this plan if the command is broadened to
`plans`.

### Step 6: Update top-level guidance if needed

Search `AGENTS.md` and `README.md` for deleted skill names:

```bash
rg -n "native-app-designer|swiftui-patterns|macos-development|preview-coverage" AGENTS.md README.md
```

If matches exist, replace them with `macos-app-engineering` where appropriate.
Do not rewrite unrelated AGENTS policy. Do not change Makefile target lists.

**Verify**:

```bash
rg -n "native-app-designer|swiftui-patterns|macos-development|preview-coverage" AGENTS.md README.md
```

Expected: no matches.

### Step 7: Run guidance validation and fix only guidance issues

Run:

```bash
make guidance-check
```

Expected: exit 0.

If it fails because of stale skill references, missing skill index rows, missing
required skill sections, or invalid links, fix those guidance files and rerun.
If it fails because a tool target disappeared or the validation script itself is
broken, STOP and report.

### Step 8: Final scope and hygiene checks

Run:

```bash
rg -n "native-app-designer|swiftui-patterns|macos-development|preview-coverage" .agents AGENTS.md README.md
git diff --check
git status --short
```

Expected:

- The `rg` command returns no operational references to deleted skills. If it
  searches `plans/`, historical plans may still mention old names; do not edit
  completed historical plans for churn.
- `git diff --check` exits 0.
- `git status --short` shows only files listed in the in-scope section and the
  deleted replaced skill directories.

Then update this plan's row in `plans/README.md` from `TODO` to `DONE` if the
operator asked you to maintain the index.

## Test plan

This is documentation/guidance work. There are no Swift tests to add.

Required verification:

- `make guidance-check` exits 0.
- `git diff --check` exits 0.
- `rg -n "native-app-designer|swiftui-patterns|macos-development|preview-coverage" .agents AGENTS.md README.md` has no operational references.
- `git status --short` contains only in-scope guidance files and deleted
  replaced skill directories.

Optional reviewer check:

- Open `.agents/skills/macos-app-engineering/SKILL.md` and confirm a weaker
  executor can answer these questions without opening any deleted skill:
  1. What skill should be used for ordinary macOS UI/app work?
  2. When should `accessibility-audit` still be used?
  3. When should `localization` still be used?
  4. When should `menubar` still be used?
  5. Which Settings containers should be used for plain lists versus composed
     content?
  6. What preview rule must every SwiftUI view satisfy?

## Done criteria

All must hold:

- [ ] `.agents/skills/macos-app-engineering/SKILL.md` exists with required
      frontmatter and sections.
- [ ] `.agents/skills/native-app-designer/`,
      `.agents/skills/swiftui-patterns/`,
      `.agents/skills/macos-development/`, and
      `.agents/skills/preview-coverage/` no longer exist.
- [ ] `.agents/SKILLS_INDEX.md` has exactly one row for
      `macos-app-engineering` and no rows for the four deleted skills.
- [ ] `.agents/docs/skill-routing.md` routes ordinary macOS UI/app work through
      `macos-app-engineering`.
- [ ] `accessibility-audit`, `localization`, `menubar`, `code-quality`,
      `swift-conventions`, `code-review`, `thermo-nuclear-code-quality-review`,
      `quality-assurance`, and `task-lifecycle` remain separate.
- [ ] `make guidance-check` exits 0.
- [ ] `git diff --check` exits 0.
- [ ] No files outside the in-scope list are modified.
- [ ] `plans/README.md` status row for plan 028 is updated.

## STOP conditions

Stop and report back instead of improvising if:

- `make guidance-check` expects the old skill names in generated or hardcoded
  validation logic that is outside this plan's in-scope files.
- The repo already contains `.agents/skills/macos-app-engineering/` with
  materially different content.
- Any deleted skill has external tooling metadata not visible in the
  `.agents/skills/<name>/SKILL.md` file.
- Consolidation appears to require changing Makefile, scripts, Swift source,
  localization files, tests, or CI config.
- You cannot make the registry and routing docs pass validation without
  reintroducing old skill names as active skills.
- You find another taxonomy/catalog file outside `.agents/skills/SKILLS_TAXONOMY.md`
  that contradicts `.agents/SKILLS_INDEX.md` and is not listed in this plan's
  scope.

## Maintenance notes

- This plan intentionally does not merge `code-quality` and `swift-conventions`.
  Their current boundary is useful: one owns language-agnostic structural
  simplification, the other owns Swift/lint/type-system conventions.
- Future UI guidance should be added to `macos-app-engineering` first. Only add
  another specialist skill when the topic has distinct verification rules or
  platform APIs, like accessibility, localization, or menu bar behavior.
- Reviewers should scrutinize the new skill for hidden mandatory chains. The
  desired outcome is one primary macOS/UI skill with specialist escalation, not
  another router that forces four files to be loaded.
