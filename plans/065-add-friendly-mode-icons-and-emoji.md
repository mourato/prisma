# Plan 065: Add friendly mode icons and emoji

## Objective

Replace the raw SF Symbol text-only mode icon input with a friendly picker for
curated SF Symbols plus a free-form emoji option, and show the selected symbol
or emoji in the mode list.

## Scope

- Define a small curated, stable SF Symbol set in the mode editor and retain
  compatibility with existing arbitrary symbols.
- Accept a single user-selected emoji without rejecting existing custom text;
  normalize and validate display safely.
- Add an accessible picker/input that clearly distinguishes SF Symbol names
  from emoji, preserves keyboard entry, and works for default/custom modes.
- Render either emoji text or a valid SF Symbol in `StylesSettingsTab` with a
  neutral fallback for invalid/empty legacy values.
- Add localization, previews, and focused model/UI tests.

## Reuse -> extend -> create

Reuse `iconSymbol` persistence, `Image(systemName:)`, existing design-system
containers, and the mode row. Create only a small icon catalog/display helper
if the repeated validation/display logic warrants it.

## Execution profile

- Recommended implementer: `implementer`
- Risk/lane: Medium / Full because this changes persisted user input and a
  primary Settings list.
- Parallelization: serial after the mode contract and Settings cleanup.
- Reviewer: required for accessibility and legacy-value behavior.
- Escalate if emoji grapheme validation causes data loss for existing symbols.

## Validation

Run focused dictation-style tests, `make preview-check`, `make build-agent`,
and the Full lane.

## Done criteria

Users can choose a curated SF Symbol or enter an emoji, the mode row displays
the chosen visual, legacy symbols remain visible, and VoiceOver has a useful
label for both forms.

