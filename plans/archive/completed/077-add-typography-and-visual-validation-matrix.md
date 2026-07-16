# Plan 077: Add typography and visual validation coverage

> **Executor instructions**: Follow this plan after Plans 073–076. Run every
> verification command before continuing. This plan may adjust presentation
> values only; do not change business behavior or persisted mode fields.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW
- **Depends on**: Plans 073, 074, 075, and 076
- **Category**: tests
- **Planned at**: commit `f9f1db2c`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: Medium/Full
- **Parallelizable**: no — validation must cover the final combined surface.
- **Reviewer required**: yes — visual acceptance requires design review.
- **Rationale**: The implementation is mostly deterministic, but typography and accessibility regressions need human review.
- **Escalate when**: Visual changes require new design-system tokens or broad unrelated settings changes.

## Why this matters

The final implementation uses `.caption2` for several explanatory and identifier texts. SwiftUI design guidance considers `.caption2` too small for many user-facing settings labels, especially with Dynamic Type. The current previews cover several trigger states but do not demonstrate Dynamic Type, Reduce Motion, reduced transparency, or all relevant window widths. This plan closes the visual verification gap.

## Current state

- `DictationStylePromptEditorView.swift:23-26` uses `.caption2` for the prompt hint.
- `DictationStyleEditorDetailView.swift:222-226` and `:294-296` use `.caption2` for user-facing hints/identifiers.
- `TriggerSelectionView.swift:145-151` and `:246-251` use `.caption2` for selected target identifiers and app bundle IDs.
- `SettingsScrollableContent.swift:96-104` has normal and narrow previews.
- `TriggerSelectionView.swift:404-527` has empty, loading, search, selected, conflict, and narrow previews.
- No final preview matrix explicitly covers Dynamic Type, Reduce Motion, or reduced transparency in the changed surfaces.

Use system text styles, `AppDesignSystem` spacing/tokens, and `.primary`/`.secondary` hierarchy. Do not replace every small metadata label blindly; promote only text needed for comprehension or interaction.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Previews | `make preview-check` | exit 0 |
| Guidance | `make guidance-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Full validation | `make validate-agent ARGS="--lane full"` | exit 0 or documented baseline failure |

## Scope

**In scope**

- `DictationStylePromptEditorView.swift`
- `DictationStyleEditorDetailView.swift`
- `TriggerSelectionView.swift`
- `ModeEditorDrawer.swift` only for preview environment variants.
- `SettingsScrollableContent.swift` preview coverage.
- Related localization only if preview labels need new text.

**Out of scope**

- Business logic, persistence, navigation architecture, and runtime matching.
- Global typography migration outside the changed Modes surfaces.
- New animation behavior; Plan 075 owns it.

## Steps

### Step 1: Review and promote overly small text

Replace `.caption2` only where the text carries instructions, state, or necessary identity. Use `.caption` or `.footnote` according to hierarchy. Keep bundle identifiers as secondary metadata only if they remain readable at larger Dynamic Type sizes.

**Verify**: `make preview-check` → no clipping or truncation in the editor/trigger previews.

### Step 2: Build the final preview matrix

Add deterministic previews for:

- normal, narrow, and expanded pane widths;
- large accessibility text size;
- Reduce Motion enabled;
- Reduce Transparency enabled;
- light and dark appearance where supported;
- empty, populated, loading, conflict, and validation-error states.

Do not use network, Keychain, hardware, or destructive persistence in previews.

**Verify**: `make preview-check` → all matrix previews compile.

### Step 3: Perform the visual acceptance review

Compare the final surface against the supplied VoiceInk reference for hierarchy, spacing, drawer width, header/footer persistence, and list readability. Record any remaining discrepancy as a follow-up rather than changing unrelated settings screens.

**Verify**: run `make preview-check`; record manual checks for narrow width, Dynamic Type, keyboard focus, VoiceOver, Reduce Motion, and reduced transparency.

### Step 4: Run the final project gates

Run guidance, build, focused tests, and the Full validation lane. Report any known baseline failure separately from new failures.

**Verify**: `make guidance-check && make build-agent && make validate-agent ARGS="--lane full"` → all pass or baseline failures are explicitly documented.

## Done criteria

- [ ] Important explanatory text no longer relies on unreadably small typography.
- [ ] Preview matrix covers width, Dynamic Type, appearance, motion, and transparency variants.
- [ ] VoiceOver/focus/reduced-motion manual checks are recorded.
- [ ] No unrelated settings screens are changed.
- [ ] Final project gates pass or known baseline failures are documented.
- [ ] `plans/README.md` is updated.

## STOP conditions

- Typography changes require a global design-system migration.
- A preview needs external services, Keychain, hardware, or persistence.
- A visual discrepancy requires changing behavior outside this plan.
- The validation lane fails with a new unrelated regression.

## Maintenance notes

Every new settings section should include at least normal and narrow previews, use system text styles, and demonstrate accessibility-sensitive states when it introduces motion, materials, or dense metadata.
