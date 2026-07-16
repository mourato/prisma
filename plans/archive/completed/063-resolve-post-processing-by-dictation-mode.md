# Plan 063: Resolve post-processing by dictation mode

## Objective

Make dictation post-processing eligibility and prompt assembly depend on the
effective `DictationStyle` selected for the active app/site, including its
per-mode enablement and prompt instructions.

## Scope

- Update `PostProcessingConfigurationProvider` and RecordingManager config
  assembly so the effective dictation mode is resolved before deciding whether
  post-processing runs.
- Remove the dictation sentinel-prompt disable branch and any now-dead
  dictation prompt-selection helpers.
- Keep readiness checks, provider/model selection, context rules, markdown,
  language, and meeting flows unchanged unless required by the new mode value.
- Add regression tests for enabled/disabled matching modes, default fallback,
  and prompt-instruction assembly.

## Reuse -> extend -> create

Reuse `effectiveDictationStyle`, `matchingDictationStyleForDictation`, and the
existing `UseCaseConfig`; extend the provider with one canonical mode-aware
decision seam. Create no parallel resolver.

## Execution profile

- Recommended implementer: `implementer`
- Risk/lane: High / Full because this changes execution behavior in recording
  and post-processing.
- Parallelization: serial after Plan 062.
- Reviewer: required; Critical/Medium findings block progression.
- Escalate if a recording session can resolve a different mode between
  configuration and execution.

## Validation

Run focused RecordingManager/post-processing tests, `make build-agent`,
`make preview-check` only if UI compilation is touched, then the Full lane.

## Done criteria

For dictation, the effective mode is the only user-facing enablement and
prompt-instruction source; meeting behavior remains covered; no dictation
runtime path depends on the old prompt-selection sentinel.

