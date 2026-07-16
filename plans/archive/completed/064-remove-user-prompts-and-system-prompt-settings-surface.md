# Plan 064: Remove user-prompts and system-prompt settings surfaces

## Objective

Remove the redundant “Prompts and post-processing” drill-down and all
dictation-facing user-prompt/system-prompt editing surfaces. Users edit the
mode prompt in `DictationStyleEditorSheet`; no Settings route or view model
offers a separate system-prompt editor for this workflow.

## Scope

- Remove `UserPromptsSettingsTab`, its dictation-only view model, and dead
  `ModesSettingsRoute` cases/navigation rows.
- Remove the post-processing drill-down from the Modes page while preserving
  the modes list/editor.
- Remove system-prompt editing from the Settings navigation and post-processing
  pages, plus orphaned view-model state and localization keys.
- Preserve meeting prompt editing where it remains a distinct meeting feature.
- Update Settings search/index/routes and focused navigation tests.

## Reuse -> extend -> create

Reuse the existing mode editor text field and native Settings list composition;
delete redundant surfaces instead of wrapping them in compatibility UI.

## Execution profile

- Recommended implementer: `implementer`
- Risk/lane: Medium / Full because Settings routes/search and user-visible
  configuration contracts change.
- Parallelization: serial after Plans 062–063.
- Reviewer: required for route/search dead-code and localization audit.
- Escalate if an external deep link or persisted route requires a compatibility
  redirect rather than removal.

## Validation

Run Settings section/search tests, `make preview-check`, `make build-agent`,
`make guidance-check` only if guidance changes, and the Full lane.

## Done criteria

No visible “User Prompts”, “System Prompt”, or “Prompts and post-processing”
dictation route remains; meeting prompt controls still work; localization has
no orphaned keys introduced by the removal.

