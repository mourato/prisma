# Plan 062: Centralize dictation post-processing in modes

## Objective

Make `DictationStyle` the canonical persisted contract for dictation mode
behavior. Add a per-mode post-processing enablement value and preserve the
existing prompt-instructions field as the user-editable mode prompt. Remove
the dictation-only prompt selection/settings contract rather than keeping a
second prompt registry.

## Scope

- `DictationStyle`, `DictationStyleEditorDraft`, default-style construction,
  normalization, UserDefaults loading/reset, and compatibility decoding.
- Migrate existing persisted dictation prompt selection/disable state into the
  default mode and then stop reading it at runtime.
- Keep meeting-specific prompt customization and meeting post-processing
  behavior intact; this plan removes the duplicate dictation user-prompt
  surface, not meeting summary prompt workflows.
- Add focused tests for decoding old modes, default values, migration, and
  per-mode persistence.

## Reuse -> extend -> create

Reuse `DictationStyle` and `DictationStyleEditorDraft`; extend them with the
smallest new field and existing initialization/migration seams. Create no new
repository or prompt abstraction.

## Execution profile

- Recommended implementer: `implementer`
- Risk/lane: High / Full because this changes persisted settings and runtime
  selection compatibility.
- Parallelization: serial; later runtime/UI plans depend on this contract.
- Reviewer: required, with the Prisma thermo-nuclear review profile.
- Escalate if legacy settings cannot be migrated without changing the default
  behavior of an existing dictation mode.

## Validation

Run focused `AppSettingsDictationStylesTests` and prompt-management tests,
`make arch-check`, `make build-agent`, and the required Full lane before merge.

## Done criteria

The mode contract carries the explicit post-processing value and prompt
instructions; old mode payloads decode safely; the default mode has an
explicit, documented value; tests prove old and new data behavior. Legacy
dictation prompt fields remain read-compatible only until Plans 063–064 remove
their consumers and settings surface.
