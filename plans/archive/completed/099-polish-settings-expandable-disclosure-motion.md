# Plan 099: Polish Form expandable disclosure motion and document the contract

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat 58783893..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppleMotion.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsExpandableSection.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppleMotionTests.swift \
>   .agents/skills/macos-app-engineering/references/macos-app-engineering-details.md \
>   .agents/skills/apple-design/references/apple-design-details.md \
>   plans/README.md
> ```
>
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/093 (DONE) — owns `SettingsExpandableSection`
- **Category**: tech-debt
- **Planned at**: commit `58783893`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent of plan 098; serialize writers per repo policy
- **Reviewer required**: `yes` — motion feel + skill guidance must stay consistent; do not regress Reduce Motion
- **Rationale**: User-visible Settings motion plus design-system token and two skill references; Full lane. Not `implementer-fast` because behavior and public `AppleMotion` surface change.
- **Escalate when**: Changing `AppleMotion.defaultSpring` / existing spring kinds becomes necessary; or call sites outside `SettingsExpandableSection` must adopt the new disclosure timing; or more than eight production Swift files need edits.

## Why this matters

`SettingsExpandableSection` (plan 093) correctly reuses design-system motion and
honors Reduce Motion, but its expand/collapse feel is inferior to the VoiceInk
`v2.0-beta.2` Form disclosure that inspired it. Root causes are not “missing
advanced animation APIs”:

1. **Wrong timing family for Form height disclosure** — the row uses
   `AppleMotion.defaultSpring` (`response: 0.35`, critically damped), which
   feels mushy when SwiftUI animates large layout-height changes. VoiceInk’s
   Form `ExpandableSettingsRow` uses a short `easeInOut(duration: 0.2)`.
2. **Stacked animation drivers** — `withAnimation` on toggle + chevron
   `.animation(_:value:)` + container `.settingsAnimated` can fight during
   height interpolation.
3. **Weaker visual nesting** — Prisma inserts a `Divider` and leaves children
   flush with the header; VoiceInk indents expanded content (top + leading)
   without a chrome divider.

Without skill guidance, the next agent will keep wiring Form disclosures to
`defaultSpring` because apple-design prefers springs for gesture surfaces.
This plan hardens a **Form disclosure motion contract** in code and docs so
the mistake does not recur.

## Current state

### Prisma expandable (shipping)

`Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsExpandableSection.swift`:

```swift
Button {
    withAnimation(SettingsMotion.sectionAnimation(reduceMotion: reduceMotion)) {
        isExpanded.toggle()
    }
} label: {
    // ...
    Image(systemName: "chevron.right")
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
        .animation(
            SettingsMotion.sectionAnimation(reduceMotion: reduceMotion),
            value: isExpanded,
        )
}
if isExpanded {
    Divider()
        .padding(.vertical, 8)
    content
        .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
}
.settingsAnimated(reduceMotion: reduceMotion, value: isExpanded)
```

`SettingsMotion.sectionAnimation` → `AppleMotion.defaultSpring` / `.default` kind
(`response: 0.35`, `dampingFraction: 1.0`).

Call sites (do **not** rewrite content trees in this plan):

- `GeneralSettingsTab` — protected apps
- `MeetingSettingsTab` — monitoring, export, prompts

### VoiceInk reference (inspiration only — do not copy GPL)

Local path: `../VoiceInk/` at ref `refs/benchmark/beingpax-v2.0-beta.2`, file
`VoiceInk/Views/Components/ExpandableSettingsRow.swift`:

- Single `withAnimation(.easeInOut(duration: 0.2))` on expand toggle
- Transition: `.opacity.combined(with: .move(edge: .top))` (or opacity-only
  for the title-only initializer)
- Expanded content: `.padding(.top, 12)` + `.padding(.leading, 4)` — **no**
  chrome `Divider`
- No Reduce Motion handling (Prisma must keep Reduce Motion)

Do **not** adopt VoiceInk’s toggle+enable coupling or `onTapGesture` row
pattern; Prisma’s `Button` + a11y traits stay.

### Tokens already in repo

`AppDesignSystem.Layout.spacing12` / `spacing4` exist for indent padding.
`AppleMotion.reduceMotionFade` is already `.easeInOut(duration: 0.2)`.

### Conventions to match

- Motion tokens live in `AppleMotion`; Settings wrappers in `SettingsMotion`.
- Exemplar tests: `AppleMotionTests.swift`.
- Skill policy: document contracts in MAE details; apple-design owns feel
  recipes (when springs vs short fades apply).
- Localization: no new user-facing copy expected.
- Benchmarking skill: VoiceInk is inspiration only — never paste GPL.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift check | see Executor instructions | empty or understood diffs only |
| Focused motion tests | `make test-agent ARGS='--filter AppleMotionTests'` | exit 0; all listed tests pass |
| Build | `make build-agent` | exit 0 |
| Guidance | `make guidance-check` | exit 0 |
| Preview canary (optional) | `make preview-check` | exit 0 or known baseline only |
| Final lane (clean tree) | `make validate-agent ARGS="--lane auto --base main --agent"` | PASS / exit 0 |

## Suggested executor toolkit

- Read `.agents/skills/delivery-workflow/SKILL.md` for lane/validation.
- Read `.agents/skills/macos-app-engineering/SKILL.md` + details for Settings
  Form / expandable contract.
- Read `.agents/skills/apple-design/SKILL.md` + details §4 (springs) and §14
  (Reduce Motion) before editing motion docs.
- Read `.agents/skills/benchmarking/SKILL.md` — VoiceInk is inspiration only.
- Do **not** invent a second expandable component or copy VoiceInk source.

## Scope

**In scope** (the only files you should modify):

- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppleMotion.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsExpandableSection.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppleMotionTests.swift`
- `.agents/skills/macos-app-engineering/references/macos-app-engineering-details.md`
- `.agents/skills/apple-design/references/apple-design-details.md`
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch, even though they look related):

- `AppleMotion.defaultSpring` / `interactiveSpring` / `pressSpring` numeric
  values — other surfaces depend on them.
- Call-site content trees in `MeetingSettingsTab` / `GeneralSettingsTab`
  (export/prompts/monitoring bodies) — do not flatten Dividers inside those
  content builders in this plan.
- VoiceInk card expand pattern (`EnhancementShortcutsSection` spring + scale)
  — that is a **different** surface; do not port scale transitions into Form
  disclosure.
- `SettingsCapabilityHeaderToggle`, Audio conditional sections, Modes side
  panel motion — leave `sectionAnimation` / `sidePanelAnimation` as they are
  unless a thin alias is needed for expandable only.
- New XCUITest / visual golden tests (plan 083 owns visual gates).
- Copying any VoiceInk GPL source into the tree.

## Git workflow

- Branch: `advisor/099-polish-settings-expandable-disclosure-motion` (or
  current feature branch if the operator already assigned one).
- Commits: Conventional Commits, atomic preferred. Examples from this repo:
  - `feat(settings): add SettingsExpandableSection for flatten IA (plan 093)`
  - `refactor(settings): fold Meetings export and prompts into root Form (plan 094)`
- Suggested split:
  1. `feat(ui): add AppleMotion disclosure timing for Form expandables (plan 099)`
  2. `refactor(settings): polish SettingsExpandableSection motion and nesting (plan 099)`
  3. `docs(skills): document Form disclosure motion contract (plan 099)`
- Do NOT push or open a PR unless the operator asks.

## Steps

### Step 1: Add a Form-disclosure motion token in `AppleMotion`

Extend `AppleMotion` **without** changing existing spring specs:

1. Add a named disclosure animation constant:
   - `public static var disclosureAnimation: Animation { .easeInOut(duration: 0.2) }`
2. Add a Reduce-Motion-aware helper parallel to `animation(reduceMotion:kind:)`:
   - `public static func disclosureAnimation(reduceMotion: Bool) -> Animation?`
   - When `reduceMotion == false` → `disclosureAnimation`
   - When `reduceMotion == true` → `reduceMotionFade` (already 0.2 easeInOut)
3. Do **not** add a new `SpringKind` case unless you also need spring math —
   Form disclosure is intentionally **not** a spring in this plan.
4. Optionally expose a short comment above the constant stating: Form/layout
   height disclosure uses short easeInOut; gesture/interruptible surfaces keep
   springs.

**Verify**:

```bash
rg -n "disclosureAnimation" Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppleMotion.swift
make test-agent ARGS='--filter AppleMotionTests'
```

→ Both symbols exist; existing AppleMotionTests still pass (update tests in
Step 4 if you add assertions in the same commit — either order is fine).

### Step 2: Route expandable motion through `SettingsMotion`

In `SettingsMotion.swift`:

1. Add expandable-specific API (names may be adjusted if clearer, but keep
   “disclosure” / “expandable” in the symbol):
   - `static func expandableAnimation(reduceMotion: Bool) -> Animation?`
     → `AppleMotion.disclosureAnimation(reduceMotion:)`
   - Keep `sectionTransition` for the transition (move+opacity / opacity) —
     that part already matches VoiceInk and apple-design spatial continuity.
2. Leave `sectionAnimation` → `defaultSpring` unchanged so capability toggles
   and other callers are not retimed by accident.
3. Do **not** change `settingsAnimated` default to disclosure globally; the
   expandable view will stop using `.settingsAnimated` for expand/collapse
   (Step 3).

**Verify**:

```bash
rg -n "expandableAnimation|sectionAnimation" Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift
```

→ `expandableAnimation` present; `sectionAnimation` still maps to
`AppleMotion.defaultSpring` / `.default`.

### Step 3: Rewrite `SettingsExpandableSection` motion + nesting

Target behavior (behavioral inspiration from VoiceInk Form row; Prisma APIs):

1. **Single animation driver**: only
   `withAnimation(SettingsMotion.expandableAnimation(reduceMotion: reduceMotion))`
   when toggling `isExpanded`. Remove:
   - chevron `.animation(..., value: isExpanded)`
   - outer `.settingsAnimated(..., value: isExpanded)`
2. Chevron still uses `rotationEffect` tied to `isExpanded` — it rides the
   same `withAnimation` transaction.
3. **Remove chrome `Divider()`** between header and content.
4. Wrap expanded content:

```swift
if isExpanded {
    content
        .padding(.top, AppDesignSystem.Layout.spacing12)
        .padding(.leading, AppDesignSystem.Layout.spacing4)
        .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
}
```

5. Keep: `Button` + `.buttonStyle(.plain)`, accessibility value
   expanded/collapsed, optional hint modifier, previews at 600/900.
6. Update the file’s DocC comment if it mentions spring/`sectionAnimation` as
   the expand driver — point to disclosure timing instead.

**Verify**:

```bash
rg -n "settingsAnimated|Divider|withAnimation|expandableAnimation|sectionAnimation" \
  Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsExpandableSection.swift
make build-agent
```

→ No `.settingsAnimated` on this view; no chrome `Divider` in the expandable
chrome; expand uses `expandableAnimation`; `make build-agent` exits 0.

### Step 4: Extend `AppleMotionTests`

Add focused assertions:

- `disclosureAnimation` exists / equals easeInOut 0.2 policy (assert via a
  documented `disclosureDuration` constant if SwiftUI `Animation` is not
  Equatable — prefer extracting
  `public static let disclosureDuration: TimeInterval = 0.2` and assert that,
  with `disclosureAnimation` built from it).
- `disclosureAnimation(reduceMotion: true)` returns the same policy as
  `reduceMotionFade` (or non-nil fade path).
- Existing spring spec tests remain unchanged (`defaultSpringSpec` still
  `0.35/1.0`).

**Verify**:

```bash
make test-agent ARGS='--filter AppleMotionTests'
```

→ exit 0; new disclosure assertions pass; spring specs unchanged.

### Step 5: Document the contract in skill references

#### A. `macos-app-engineering-details.md` — under “Flatten IA: expandable…”

Add a short **Motion contract for `SettingsExpandableSection`** bullet list:

- Use `SettingsMotion.expandableAnimation(reduceMotion:)` /
  `AppleMotion.disclosureAnimation` — **not** `sectionAnimation` /
  `defaultSpring`.
- Drive expand/collapse with a **single** `withAnimation` (no stacked
  `.animation` / `.settingsAnimated` on the same disclosure).
- Transition: `sectionTransition` (move from top + opacity; opacity-only when
  Reduce Motion).
- Nest expanded content with top `spacing12` + leading `spacing4`; do **not**
  insert a chrome `Divider` in the expandable primitive (content may still
  contain its own separators).
- VoiceInk `v2.0-beta.2` Form `ExpandableSettingsRow` is behavioral inspiration
  only (short easeInOut disclosure) — do not copy GPL; do not confuse with
  VoiceInk **card** expands that use spring + scale.
- Keep `Button` accessibility traits; honor Reduce Motion.

#### B. `apple-design-details.md` — near §4 (springs) or §14 (Reduce Motion)

Add a short “Settings Form disclosure” exception:

- Prefer springs for gesture-driven / interruptible surfaces.
- For **Form row height disclosure** (show/hide nested settings under a
  header), prefer a short `easeInOut(~0.2s)` via `AppleMotion.disclosureAnimation`
  because layout-height interpolation reads mushy with `defaultSpring` (0.35).
- Reduce Motion still substitutes opacity-only transition + fade timing.
- Do not stack multiple animation modifiers for one disclosure toggle.

Do **not** bloat `SKILL.md` entrypoints — keep the recipe in the reference
files only (matches plan 085 progressive disclosure).

**Verify**:

```bash
make guidance-check
rg -n "disclosureAnimation|SettingsExpandableSection|Form disclosure|expandableAnimation" \
  .agents/skills/macos-app-engineering/references/macos-app-engineering-details.md \
  .agents/skills/apple-design/references/apple-design-details.md
```

→ `guidance-check` exit 0; both files mention the disclosure contract.

### Step 6: Ledger + optional preview smoke

1. Update `plans/README.md` status row for 099 → `DONE` (or `IN PROGRESS`
   while working; `DONE` when criteria below hold).
2. Optionally open `#Preview("Expandable Section — 600")` in Xcode / run
   `make preview-check` — expand/collapse should feel snappy; Reduce Motion
   should fade without slide.

**Verify**:

```bash
rg -n "099" plans/README.md
make validate-agent ARGS="--lane auto --base main --agent"
```

→ Status row present; validate-agent PASS on a clean tree (or follow
delivery-workflow: commit then trust pre-push if operating Low slice — this
plan is Medium/Full, so prefer one validate-agent before handoff).

## Test plan

- Extend `AppleMotionTests` as in Step 4 (unit-level token contract).
- No new XCTest for the SwiftUI view body unless a pure layout helper is
  extracted (prefer not extracting).
- Manual (executor or reviewer):
  - Settings → Meetings: expand/collapse Monitoring, Export, Prompts — snappy,
    indented, no extra chrome divider from the primitive.
  - Settings → General: Protected apps expand.
  - Enable Reduce Motion: opacity-only, no slide; still usable.
  - VoiceOver: header still announces expanded/collapsed.

## Done criteria

- [ ] `AppleMotion` exposes disclosure timing (`disclosureDuration` /
  `disclosureAnimation` + reduce-motion helper) without changing
  `defaultSpringSpec` / `interactiveSpringSpec` / `pressSpringSpec`
- [ ] `SettingsExpandableSection` uses a **single** `withAnimation` via
  `SettingsMotion.expandableAnimation`; no stacked `.settingsAnimated` /
  chevron `.animation` for expand
- [ ] Chrome `Divider` removed from the expandable primitive; content padded
  with `spacing12` top + `spacing4` leading
- [ ] `make test-agent ARGS='--filter AppleMotionTests'` exits 0 with new
  disclosure assertions
- [ ] `make build-agent` exits 0
- [ ] `make guidance-check` exits 0
- [ ] MAE + apple-design reference docs document the Form disclosure contract
  and the VoiceInk Form vs card distinction
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row for 099 → DONE

## STOP conditions

Stop and report back (do not improvise) if:

- Drift check shows in-scope files diverged from the excerpts / assumptions.
- Existing call sites break because they relied on the chrome `Divider` for
  visual separation and product rejects the indent-only nesting — pause for
  product decision rather than re-adding the Divider silently in one tab only.
- Fix appears to require changing `defaultSpring` globally or retiming
  `SettingsCapabilityHeaderToggle` / Audio section transitions.
- Someone requests porting VoiceInk spring+scale card expand into Form — that
  is a different pattern; stop and open a separate plan.
- `make guidance-check` fails for unrelated guidance drift — report; do not
  “fix” unrelated skill files under this plan.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- Future expandable polish should edit `AppleMotion.disclosure*` /
  `SettingsMotion.expandableAnimation` — not invent local
  `.easeInOut(duration:)` inside views.
- Reviewers should reject PRs that wire `SettingsExpandableSection` (or new
  Form disclosures) to `AppleMotion.defaultSpring` / `sectionAnimation`.
- Plan 083 (visual gates) may later snapshot expandable open/closed states;
  this plan deliberately skips goldens.
- If product later wants enable-toggle-coupled expand (VoiceInk Power Mode
  style), that is a separate interaction plan — do not overload this primitive
  without a Binding for `isEnabled`.
