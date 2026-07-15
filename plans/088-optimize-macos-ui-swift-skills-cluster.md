# Plan 088: Optimize the macOS UI / Apple design / Swift skills cluster

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer maintains the index.
>
> **Drift check (run first)**:
> `git diff --stat 9e006e07..HEAD -- .agents/skills/macos-app-engineering .agents/skills/apple-design .agents/skills/swiftui-pro .agents/skills/swift-conventions .agents/skills/accessibility-audit .agents/docs/skill-routing.md .agents/SKILLS_INDEX.md .agents/docs/archive/skills-taxonomy-2026-07-15.md AGENTS.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live files before proceeding; on a
> mismatch, treat it as a STOP condition.
>
> **Decision gate**: Default path is **Option B** (fold `swiftui-pro` into
> `macos-app-engineering` as a review appendix; keep and slim `apple-design`;
> keep `swift-conventions`). If the operator selected **Option A** or
> **Option C** in the advising session, follow the matching STOP/alternate
> branch in Step 0 — do not invent a fourth topology.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/028-consolidate-macos-ui-guidance-skills.md (DONE),
  plans/084-slim-always-on-agent-guidance-and-validation-loop.md (DONE),
  plans/085-finish-progressive-disclosure-and-prune-skill-bulk.md (DONE)
- **Category**: dx / docs / direction
- **Planned at**: commit `9e006e07`, 2026-07-15
- **Completed**: Option B implemented on `docs/088-macos-ui-skills-cluster-overlap`;
  low-utility `.agents/docs/archive/` trees deleted (no recovery copy retained).
- **Worktree / branch**: `.worktrees/macos-ui-skills-overlap` /
  `docs/088-macos-ui-skills-cluster-overlap`

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `no` — one writer; ownership/routing edits must stay coherent
- **Reviewer required**: `yes` — judgment calls on what unique content to keep
  vs archive; risk of deleting still-used review heuristics
- **Rationale**: Guidance-only (no product source). Not `implementer-fast`
  because prune/merge decisions are judgment-heavy (same rationale as plan 085).
- **Escalate when**: Unique Prisma rules are found only inside content marked
  for archive/deletion, or the operator demands merging `apple-design` into
  `macos-app-engineering` (Option C) after bulk already returned once.

## Why this matters

Plan 028 collapsed four overlapping UI skills into `macos-app-engineering` and
kept true specialists separate. Plans 084/085 then slimmed always-on guidance
and pruned hot-path reference bulk. After that cleanup, two new skills entered
the same thematic cluster: `apple-design` (interaction/motion feel) and
`swiftui-pro` (SwiftUI review heuristics).

The cluster now has clear *labels* but muddy *content ownership*. Loading
`macos-app-engineering` + `apple-design` + `swiftui-pro` for ordinary UI work
pulls ~1.1k lines with repeated Reduce Motion, Dynamic Type, springs/animation,
SwiftUI state, and Swift-style advice — while `accessibility-audit` and
`swift-conventions` already own audit accessibility and Swift language rules.
Agents either under-load (miss a specialist) or over-load (conflicting /
iOS-tilted advice). This plan restores the 028 principle: one primary
implementation owner, thin specialists with unique depth, no re-owned topics.

## Current state

### Measured sizes at `9e006e07`

| Skill / path | Lines | Role claimed by routing |
|---|---:|---|
| `macos-app-engineering/SKILL.md` | 68 | Primary macOS UI/app implementation |
| `macos-app-engineering/references/macos-app-engineering-details.md` | 123 | Prisma Settings, composition, AppKit, previews |
| `apple-design/SKILL.md` | 65 | Interaction / motion / materials / typography |
| `apple-design/references/apple-design-details.md` | 439 | WWDC fluid-interfaces essay (UIKit + SwiftUI) |
| `swiftui-pro/SKILL.md` | 121 | SwiftUI review process owner |
| `swiftui-pro/references/*.md` (9 files) | ~288 | Generic review heuristics (partially Prisma-patched) |
| `swift-conventions/SKILL.md` | 102 | Swift style / type safety / modules |
| `accessibility-audit/SKILL.md` | 77 | Accessibility audit owner |

Hot-path load if an agent attaches MAE + apple-design + swiftui-pro entrypoints
only: ~254 lines. If it also opens details/refs: ~1.1k lines.

### Historical decisions (do not reopen without cause)

- Plan 028: merge `native-app-designer` / `swiftui-patterns` / `macos-development` /
  `preview-coverage` → `macos-app-engineering`; keep `accessibility-audit`,
  `localization`, `menubar`, `swift-conventions` separate.
- Plan 085: progressive disclosure + archive generic MAE reference dumps under
  `.agents/docs/archive/macos-app-engineering-references-2026-07-15/`.
- Archived taxonomy
  (`.agents/docs/archive/skills-taxonomy-2026-07-15.md`) still says keep both
  `apple-design` and `swiftui-pro` as specialists — that was before this
  content-level overlap audit.

### Overlap matrix (evidence-backed)

| Topic | Canonical owner today | Also restated in | Severity |
|---|---|---|---|
| Settings / design-system / previews / AppKit lifecycle | `macos-app-engineering` | — | Clean |
| SwiftUI composition & state (`@StateObject` vs Observation) | `macos-app-engineering` details | `swiftui-pro` `data.md` (pushes Observation harder; conflicts with MAE preserve-ObservableObject rule) | High |
| Body performance / list identity | `macos-app-engineering` details | `swiftui-pro` `performance.md` | Medium |
| Springs / interruptible gestures / velocity handoff | `apple-design` details §§1–10 | MAE “Motion…” (thin); `swiftui-pro` `views.md` Animating | Medium (depth unique to apple-design) |
| Reduce Motion | `accessibility-audit` (audit) + apple-design §14 (implementation recipes) | MAE motion bullets; `swiftui-pro` `accessibility.md` | High (3–4 homes) |
| Dynamic Type / typography | `apple-design` §15 | `swiftui-pro` `accessibility.md` + `design.md` | Medium |
| VoiceOver / keyboard / focus | `accessibility-audit` | `swiftui-pro` `accessibility.md` (generic) | Medium |
| Modern SwiftUI API (`foregroundStyle`, etc.) | nowhere Prisma-owned uniquely | `swiftui-pro` `api.md` only | Keep as unique value |
| Swift style / force-unwrap / naming | `swift-conventions` | `swiftui-pro` `swift.md` | High |
| Concurrency (`Task.sleep`, `Task.detached`) | `swift-concurrency-expert` + AGENTS | `swiftui-pro` `swift.md` Concurrency section | High |
| File-per-type / extract View structs | `swift-conventions` + MAE | `swiftui-pro` `views.md` (also demands one type per file aggressively) | Medium |
| iOS/UIKit examples (`UIScreen`, `UIKit` haptics, `UIViewPropertyAnimator`) | — | `apple-design` details heavily; `swiftui-pro` design/api | High noise for macOS 15 app |

### Ownership claims that currently conflict

```text
.agents/skills/macos-app-engineering/references/macos-app-engineering-details.md:27-29
- Own reference-type state with `@StateObject`; pass externally owned objects with `@ObservedObject` or environment.
- Keep UI-bound state on the main actor.
```

```text
.agents/skills/swiftui-pro/references/data.md:10-12
- All shared data should use `@Observable` classes with `@State` (for ownership) and `@Bindable` / `@Environment` (for passing).
- Strongly prefer not to use `ObservableObject`, `@Published`, `@StateObject`, …
```

Prisma policy (AGENTS.md + MAE): prefer Observation for *new* state; preserve
`ObservableObject` until intentional migration. `swiftui-pro` currently reads
as “ban ObservableObject,” which fights the project rule.

```text
.agents/skills/apple-design/SKILL.md:22-24
Trigger for … Dynamic Type or tracking/leading work, Reduce Motion behavior, …
```

```text
.agents/skills/accessibility-audit/SKILL.md:21-24
- reduced-motion behavior
…
### Motion and Visual Signals
- Honor reduced-motion settings for animation-heavy surfaces.
```

`apple-design` should own *how motion feels and how to fall back*;
`accessibility-audit` should own *whether the surface passes an a11y audit*.
Both currently claim Reduce Motion as a primary trigger.

### What is uniquely valuable (do not delete blindly)

**Keep under `apple-design` (unique depth):**
- Interruptibility, velocity handoff, momentum projection, rubber-banding
- Critically damped vs underdamped spring tables
- Spatial consistency / gesture-feel checklist
- Materials/depth as hierarchy (when not already covered by DS tokens)

**Keep from `swiftui-pro` (unique review heuristics):**
- Modern API substitutions (`foregroundStyle`, `clipShape(.rect…)`, `onChange` arity, `@Entry`)
- Review process checklist shape (file-ordered findings + prioritized summary)
- A few performance anti-patterns not in MAE (`AnyView`, ternary vs `_ConditionalContent`, escaping `@ViewBuilder` storage)

**Do not keep as separate skill content:**
- Generic Swift style already in `swift-conventions`
- Concurrency remediation already in `swift-concurrency-expert`
- Full a11y checklist already in `accessibility-audit`
- SwiftData/CloudKit sections (not Prisma’s path)
- Links to external twostraws sibling skills as required reading

### Options considered

| Option | Action | Pros | Cons | Verdict |
|---|---|---|---|---|
| **A — Boundary-only** | Keep all four skills; rewrite scopes so content does not re-own topics | Lowest churn | Agents still face four triggers; bulk remains | Acceptable fallback |
| **B — Fold `swiftui-pro` into MAE** | Move unique review/API heuristics into `macos-app-engineering/references/swiftui-review.md`; delete `swiftui-pro`; slim `apple-design` to macOS-first motion/feel; keep `swift-conventions` | Matches plan 028; removes worst overlap offender; preserves motion specialist | Need careful routing/index updates | **Recommended default** |
| **C — Fold both specialists into MAE** | Merge apple-design + swiftui-pro into MAE references | Fewest skills | Re-inflates MAE after 085 pruned it; motion essay is deep reference, not hot-path | Reject unless operator insists |

**Rejected now:** merging `swift-conventions` into this cluster — split with
`code-quality` is clean (language-specific vs generic readability). Do not reopen.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Guidance | `make guidance-check` | exit 0 |
| Lane preview | `make validate-agent ARGS="--lane auto --dry-run --base main"` | guidance-only / Fast strategy, exit 0 |
| Fast gate | `make validate-agent ARGS="--lane fast --agent"` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |
| Orphan name hunt | `rg -n "swiftui-pro" .agents AGENTS.md plans/README.md` | only expected historical plan mentions + archive notes |

## Suggested executor toolkit

- `project-standards` for skill template section order and AGENTS/routing sync.
- `macos-app-engineering` while editing its own tree.
- `documentation` only if DocC/MARK style questions arise (unlikely).
- Do **not** load full `apple-design` details + all `swiftui-pro` refs into
  context at once while editing — work section-by-section.

## Scope

**In scope** (Option B default):

- `.agents/skills/macos-app-engineering/SKILL.md`
- `.agents/skills/macos-app-engineering/references/macos-app-engineering-details.md`
- `.agents/skills/macos-app-engineering/references/swiftui-review.md` (create)
- `.agents/skills/apple-design/SKILL.md`
- `.agents/skills/apple-design/references/apple-design-details.md`
- `.agents/skills/swiftui-pro/` (delete after content migration; or move tree to
  `.agents/docs/archive/swiftui-pro-2026-07-15/` if archival preferred over delete)
- `.agents/skills/accessibility-audit/SKILL.md` (Related Skills / trigger clarity only)
- `.agents/skills/swift-conventions/SKILL.md` (Related Skills touch only if needed)
- `.agents/docs/skill-routing.md`
- `.agents/SKILLS_INDEX.md` (if present and still live)
- `AGENTS.md` only if it names `swiftui-pro` or the cluster incorrectly
- `plans/README.md` (status row)
- Optional archive note under `.agents/docs/archive/` documenting the 088 decision

**Out of scope**:

- Product Swift/SwiftUI source under `App/` or `Packages/`
- Merging `menubar`, `localization`, or `accessibility-audit` into MAE
- Merging `swift-conventions` with `code-quality`
- Re-expanding archived MAE generic dumps from
  `.agents/docs/archive/macos-app-engineering-references-2026-07-15/`
- Global Codex skills outside this repo
- Rewriting the entire apple-design WWDC essay from scratch (slim/annotate only)

## Git workflow

- Branch: `docs/088-macos-ui-skills-cluster-overlap` (already created for this
  advisory worktree)
- Commit style: Conventional Commits, e.g.
  `docs(guidance): fold swiftui-pro into macos-app-engineering review appendix`
- Do **not** push or open a PR unless the operator asks

## Steps

### Step 0: Confirm option and freeze inventory

1. Confirm operator choice: **B (default)**, **A**, or **C**.
2. If **A**: skip Steps 2–4 deletion/migration; execute only Step 1 boundary
   rewrites + Step 5 routing + Step 6 validation, then stop.
3. If **C**: STOP and report — rewrite this plan’s Steps 2–4 to merge
   apple-design into MAE with an explicit line budget (suggest ≤200 lines in
   MAE details + a single `apple-interaction.md` reference ≤250 lines) before
   continuing.
4. Capture a pre-edit inventory:

```bash
wc -l .agents/skills/macos-app-engineering/SKILL.md \
  .agents/skills/macos-app-engineering/references/*.md \
  .agents/skills/apple-design/SKILL.md \
  .agents/skills/apple-design/references/*.md \
  .agents/skills/swiftui-pro/SKILL.md \
  .agents/skills/swiftui-pro/references/*.md \
  .agents/skills/swift-conventions/SKILL.md \
  .agents/skills/accessibility-audit/SKILL.md
```

**Verify**: inventory printed; option recorded in the commit message body or
plan status note.

### Step 1: Clarify live ownership contracts (all options)

Update entrypoint `SKILL.md` files so each has a one-sentence exclusive claim:

| Skill | Exclusive claim |
|---|---|
| `macos-app-engineering` | Ordinary macOS UI/app *implementation* (SwiftUI composition, Settings/DS, AppKit bridge, previews, lifecycle) |
| `apple-design` | Interaction *feel* (gestures, springs, interruptibility, materials/depth, typography metrics) — not Settings/DS ownership |
| `accessibility-audit` | Accessibility *audit pass/fail* (VoiceOver, keyboard/focus, Reduce Motion compliance, overlays) |
| `swift-conventions` | Swift *language* style, type safety, module/file naming |
| `swiftui-pro` (Option A only) | SwiftUI *review findings format* + modern API checklist; must not restate MAE/a11y/conventions |

For Option B, after deletion, MAE’s Related Skills should list
`apple-design`, `accessibility-audit`, `swift-conventions` (not `swiftui-pro`).

Tighten apple-design When to Use so Reduce Motion / Dynamic Type are
“implementation recipes for motion/type,” with explicit route to
`accessibility-audit` for audits.

**Verify**:
`rg -n "Own the|Scope Boundary|When to Use" .agents/skills/macos-app-engineering/SKILL.md .agents/skills/apple-design/SKILL.md .agents/skills/accessibility-audit/SKILL.md`
→ each file still has Role / Scope / When to Use; no skill claims exclusive
ownership of another’s exclusive claim above.

### Step 2 (Option B): Create MAE SwiftUI review appendix

Create `.agents/skills/macos-app-engineering/references/swiftui-review.md` as a
**routed reference** (no YAML skill frontmatter, no Role/When to Use duplicate).

Migrate **only** unique content from `swiftui-pro/references/`:

- From `api.md`: modern API substitutions, adapted to macOS 15 minimum /
  macOS 26 availability (drop iOS-only WebView / navigationBar items that do
  not apply; replace with macOS-relevant notes or omit).
- From `views.md`: extract-View-struct + animation(`_:value:`) rules that are
  not already in MAE details; drop “one type per file” duplication of
  `swift-conventions` beyond one cross-link.
- From `performance.md`: `AnyView`, ternary vs branching identity, escaping
  `@ViewBuilder` storage — keep short.
- From `data.md`: keep Binding/`onChange` hygiene; **rewrite** Observation
  guidance to match AGENTS/MAE (“prefer Observation for new state; preserve
  ObservableObject until intentional migration”). Delete SwiftData sections.
- From `SKILL.md` output format: keep the file-ordered finding template as a
  “when reviewing” section.
- Do **not** copy `accessibility.md`, `swift.md` concurrency, or design.md
  touch-target iOS rules — replace with one-liners routing to
  `accessibility-audit` / `swift-conventions` / MAE design-system sections.

Add a row to MAE’s Routed references table pointing at `swiftui-review.md` for
“SwiftUI API / review pass”.

**Verify**:
`test -f .agents/skills/macos-app-engineering/references/swiftui-review.md`
`rg -n "SwiftData|UIScreen|twostraws|ObservableObject` ban|Strongly prefer not to use \`ObservableObject\`" .agents/skills/macos-app-engineering/references/swiftui-review.md`
→ no matches (or only a sentence that preserves ObservableObject per AGENTS).

### Step 3 (Option B): Slim `apple-design` for macOS-first progressive disclosure

1. Remove duplicate Role/Scope/When to Use / YAML skill frontmatter from
   `apple-design-details.md` if still present (match plan 085 MAE details
   cleanup pattern — details are a reference, not a second skill).
2. At the top of details, add a short “Platform note”: Prisma is macOS 15+;
   prefer SwiftUI/AppKit examples; treat UIKit snippets as conceptual unless
   the surface is explicitly UIKit-bridged.
3. In §14 Reduce Motion and §15 Typography, add one-line routes to
   `accessibility-audit` for audit work; keep the implementation recipes.
4. Do not expand MAE’s motion section beyond a thin pointer to apple-design —
   avoid re-copying spring tables into MAE.

Target budgets after slim (soft):
- `apple-design/SKILL.md` ≤ 80 lines
- `apple-design-details.md` ≤ 400 lines (prefer cutting UIKit-only duplicate
  examples rather than unique principles)

**Verify**:
`wc -l .agents/skills/apple-design/SKILL.md .agents/skills/apple-design/references/apple-design-details.md`
→ within soft budgets or justified in the handoff if slightly over.
`rg -n "^name:|^## Role|^## When to Use" .agents/skills/apple-design/references/apple-design-details.md`
→ no skill frontmatter / Role / When to Use headers in details.

### Step 4 (Option B): Retire `swiftui-pro` and rewrite routers

1. Archive or delete `.agents/skills/swiftui-pro/` (prefer archive under
   `.agents/docs/archive/swiftui-pro-2026-07-15/` so content is recoverable).
2. Update `.agents/docs/skill-routing.md`:
   - Remove `swiftui-pro` from General Routing Priority and UI/UX escalation.
   - Point “SwiftUI review / modern API” to `macos-app-engineering` +
     `swiftui-review.md`.
   - Keep `apple-design` for motion/feel escalation.
3. Update `.agents/SKILLS_INDEX.md` if it still lists skills.
4. Update Related Skills links in MAE, apple-design, accessibility-audit.
5. Add a short archive note (new file or appendix) that plan 088 superseded the
   “keep swiftui-pro” row in
   `.agents/docs/archive/skills-taxonomy-2026-07-15.md` — do **not** rewrite
   the archived taxonomy in place; leave history intact and point forward.

**Verify**:
`test ! -f .agents/skills/swiftui-pro/SKILL.md`
`rg -n "swiftui-pro" .agents/docs/skill-routing.md .agents/SKILLS_INDEX.md AGENTS.md .agents/skills --glob '!**/archive/**'`
→ no live routing references (historical plans may still mention the name).

### Step 5: Align `swift-conventions` touchpoints

Ensure `swift-conventions` Related Skills still points at `code-quality`, and
that MAE/swiftui-review route Swift naming/file rules there instead of
duplicating lint budgets.

**Verify**:
`rg -n "swift-conventions|code-quality" .agents/skills/macos-app-engineering/SKILL.md .agents/skills/macos-app-engineering/references/swiftui-review.md`
→ at least one explicit route.

### Step 6: Validate guidance and lane

```bash
make guidance-check
git diff --check
make validate-agent ARGS="--lane auto --dry-run --base main"
make validate-agent ARGS="--lane fast --agent"
```

**Verify**: all exit 0; dry-run classifies as guidance-only / Fast.

### Step 7: Update plan ledger

Update `plans/README.md`: add row 088, set Status `DONE` when complete, note
next plan number becomes 089, and add a dependency note that 088 supersedes
the archived taxonomy’s “keep swiftui-pro” recommendation for live routing.

## Test plan

Guidance-only — no XCTest changes.

Manual checks:

1. Cold-read MAE `SKILL.md`: can an agent implement a Settings row without
   opening apple-design or the review appendix? (Yes expected.)
2. Cold-read apple-design: does it still teach velocity handoff without owning
   Settings DS components? (Yes expected.)
3. Cold-read swiftui-review appendix: does it avoid banning ObservableObject
   contrary to AGENTS? (Yes expected.)
4. `rg` orphan check for `swiftui-pro` in live routing paths (Step 4 verify).

## Done criteria

- [ ] Operator option recorded; default B executed unless A/C explicitly chosen
- [ ] Exclusive ownership claims in Step 1 hold for remaining skills
- [ ] Option B: `swiftui-review.md` exists; `swiftui-pro` skill tree not live
- [ ] Option B: skill-routing and index no longer escalate to `swiftui-pro`
- [ ] `apple-design` details are reference-shaped (no second skill frontmatter)
- [ ] No product source files modified
- [ ] `make guidance-check` exits 0
- [ ] `make validate-agent ARGS="--lane fast --agent"` exits 0
- [ ] `plans/README.md` status row for 088 updated

## STOP conditions

- Drift check shows ownership model already changed (e.g. `swiftui-pro`
  already removed) — reconcile, do not duplicate.
- Operator selects Option C — rewrite merge budgets before editing.
- A Prisma-specific rule exists only inside content slated for archive and has
  no home after migration — relocate into MAE/apple-design/a11y first.
- `make guidance-check` fails for reasons outside in-scope files — report,
  do not “fix” unrelated guidance.
- Temptation to re-import archived generic MAE dumps — refuse.

## Maintenance notes

- Future UI skills should escalate through `macos-app-engineering` first;
  add a specialist only when depth is unique and hot-path bulk stays out of
  the specialist’s `SKILL.md` entrypoint (plan 085 pattern).
- Reviewers should reject PRs that reintroduce a parallel “SwiftUI patterns”
  skill without updating this plan’s ownership table.
- If Observation migration (plan 040) completes repository-wide, then — and
  only then — harden the review appendix’s ObservableObject language.
- Deferred: measured token/cost impact of the cluster change (needs evaluator
  from plan 058); do not claim savings without measurement.
