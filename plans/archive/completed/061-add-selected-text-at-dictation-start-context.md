# Plan 061: Add opt-in selected-text-at-start context for dictation

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat c6307fff..HEAD -- <in-scope paths>`
> The prompt/context-hardening changes may still be uncommitted in the working
> tree. Compare the live files with the Current state below before editing. Do
> not discard those changes.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none; integrate after the current prompt/context-hardening work is preserved
- **Category**: direction
- **Planned at**: commit `c6307fff`, 2026-07-13

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — capture timing, persisted context items, style policy, and prompt payload must be changed as one contract
- **Reviewer required**: yes — the change combines Accessibility capture, privacy-sensitive data, persistence compatibility, and recording-start concurrency
- **Rationale**: This is a cross-module behavior change touching UI, settings serialization, context capture, recording lifecycle, prompt assembly, and tests. It is not deterministic Fast-lane work.
- **Escalate when**: the implementation requires a Core Data schema migration, changes meeting context behavior, blocks recording on Accessibility failure, or captures full focused/visible text instead of selected text only

## Why this matters

Dictation users may start recording while a relevant sentence, code fragment, file name, or message is selected in the active app. Capturing that selection at the exact start of dictation gives post-processing a stable lexical/reference source, unlike the current post-start focused-text capture that can observe a different UI state or return the whole visible text. The feature must be opt-in, privacy-safe, persisted with the transcription, and explicitly described to the model as disambiguation context rather than content or instructions.

## Current state

Relevant files and contracts:

- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift:3-70` — `DictationContextSourcePolicy` is Codable and currently stores `includeClipboard`, `includeWindowOCR`, `includeAccessibilityText`, and `redactSensitiveData`; missing decoded fields default safely.
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift:158-230` — `DictationStyle` persists the context policy inside the dictation-style JSON payload.
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorSheet.swift:245-252,350-390` — the existing Context Sources group uses `CheckboxRow` controls and saves a `DictationContextSourcePolicy` through `DictationStyleEditorDraft`.
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift:6-43,70-134` — the editor draft copies policy values into and out of `DictationStyle`.
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerContextCapture.swift:40-72` — post-start context capture currently replaces `postProcessingContext` and `postProcessingContextItems` after recording has begun; this must become a merge so a start-time item is not lost.
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerContextCapture.swift:104-157` — deferred OCR also appends a context block while recording; its append path must preserve the typed context format.
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift:180-222` — `prepareAndStartRecording` resolves the active app and creates `currentMeeting` before `startRecorder`; this is the insertion point for selected-text capture, before the recorder starts and before focus can change.
- `Packages/MeetingAssistantCore/Sources/UI/Services/AssistantContextCaptureService.swift:19-39,202-222` — owns the injected `TextContextProvider`, guardrails, redaction, and Accessibility failure behavior. Reuse this boundary for selected-text capture.
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/TextContextProtocols.swift:10-12` — `TextContextProvider` is the existing protocol boundary for Accessibility text acquisition.
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/AXTextContextProvider.swift:32-86,200+` — the provider currently returns full/visible focused-element text and caches it. The new operation must read only `kAXSelectedTextAttribute`, bypass the full-text cache, and return no item when there is no selection.
- `Packages/MeetingAssistantCore/Sources/Domain/Models/Transcription.swift:235-255` — `TranscriptionContextItem.Source` is the persisted source taxonomy. Add a distinct `selectedTextAtStart` case; do not overload `.accessibilityText` or `.focusedText`.
- `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/TranscriptionMO.swift:125-159,252-259` — context items are JSON encoded into the existing optional `contextItemsData` binary attribute. A new enum case should require no Core Data model migration, but round-trip coverage is mandatory.
- `Packages/MeetingAssistantCore/Sources/Domain/Models/AIPromptTemplates.swift` — current prompt/context hardening defines typed metadata blocks and says context is disambiguation-only. Add the new typed block to that contract.

Important decisions for the executor:

1. The setting is a dictation-source setting, not a meeting source. Add it to the existing per-dictation-style Context Sources editor. The default style is opt-in false for privacy and backward compatibility.
2. Persist the setting as `includeSelectedTextAtStart` inside `DictationContextSourcePolicy`; do not add a second global preference unless the current default-style construction proves it cannot preserve the value.
3. Capture selected text only at dictation start. Do not reuse the existing full focused/visible-text result, do not poll during recording, and do not capture this source for meeting recordings.
4. Store the captured value as `TranscriptionContextItem(source: .selectedTextAtStart, text: ...)` and serialize it as `<SELECTED_TEXT_AT_START>...</SELECTED_TEXT_AT_START>` inside `<CONTEXT_METADATA>`.
5. Capture failure, missing Accessibility permission, protected app, no focused element, and empty selection must all be non-fatal: recording continues without the item. Never log the text value.

Repository conventions to follow:

- Use `reuse → extend → create`: extend the existing text-context boundary and context-item taxonomy before creating a new service.
- Use checkboxes for persisted settings forms, matching `DictationStyleEditorSheet.swift:245-252`.
- Use `.localized` for every user-facing string and add matching English and Portuguese entries.
- Preserve native settings containers and existing dictation-style taxonomy.
- Keep structured concurrency; do not introduce `DispatchQueue` or a detached task for Accessibility capture.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused policy/context tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'DictationStyle|ContextAwareness|PromptService|Transcription.*Context'` | All selected tests pass |
| Prompt/context regression tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'PromptServiceTests|ContextAwarenessServiceTests|PostProcessingSystemContextMetadataTests'` | All selected tests pass |
| Preview validation | `make preview-check` | Exit 0 |
| Narrow build | `make build-agent` | Exit 0 |
| Guidance/localization integrity | `make guidance-check` | Exit 0 when guidance/resources are changed |
| Final Full gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | Lint passes and build-test passes; known baseline failures must be reported, not hidden |

## Scope

**In scope** (modify only as required by the steps):

- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/Defaults.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/ContextWebTargets.swift` if default-style construction requires it
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorSheet.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/AssistantContextCaptureService.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerContextCapture.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/TextContextProtocols.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/TextContext.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/AXTextContextProvider.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/Transcription.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/AIPromptTemplates.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- focused tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`

**Out of scope**:

- Meeting-recording context behavior.
- `AssistantTextSelectionService`, which edits selected text for Assistant commands and has a different lifecycle.
- Capturing clipboard contents as a substitute for selected text.
- Full focused/visible-text capture changes unrelated to this source.
- Core Data model/schema changes unless the existing JSON round-trip cannot represent the new source case; stop and report before adding a migration.
- New settings taxonomy, new navigation routes, or a new context service without first proving the existing boundaries cannot support the feature.

## Steps

### Step 1: Extend the persisted dictation-source contract

Add `includeSelectedTextAtStart: Bool` to `DictationContextSourcePolicy`, its `CodingKeys`, initializers, `hasEnabledContextSources`, decoder default (`false` for old payloads), and encoder. Update `DictationStyle`/draft/default-style construction so the field is copied without being dropped during create, edit, normalization, reset, or reload. Add `TranscriptionContextItem.Source.selectedTextAtStart` and a localized display label used by transcription context UI. Confirm existing JSON payloads without the field still decode unchanged.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'DictationStyle|Transcription.*Context'` → legacy decode, round-trip, and source taxonomy tests pass.

### Step 2: Add the opt-in UI and localization

Add a `CheckboxRow` to the existing Context Sources group in `DictationStyleEditorSheet.swift`. Use copy that clearly says the selected text is captured once when dictation starts and sent as AI context; explain that Accessibility permission is required and that the source is not continuously monitored. Add English and Portuguese title, description, and accessibility strings. Ensure the checkbox value flows through `DictationStyleEditorDraft` and is visible/editable for both the default and custom dictation styles. Add or update settings search keys only if the new localized key is independently searchable under the existing editor context-source family.

**Verify**: `make preview-check` → settings previews compile; focused style editor/view-model tests confirm false-by-default and save/reload preservation.

### Step 3: Implement selected-only capture at recording start

Extend the existing `TextContextProvider` boundary with a selected-only operation, or stop and report if the generated-mock/tooling contract makes that unsafe. Implement it in `AXTextContextProvider` by reading only `kAXSelectedTextAttribute` from the focused element at call time. Do not use the existing full-text cache, visible-range fallback, or `kAXValueAttribute`. Return an empty/nil result for no selection and preserve existing exclusion/permission checks. Apply `TextContextGuardrails` and sensitive-data redaction through `AssistantContextCaptureService`; failures must be logged with a reason code only, never with text.

Call this operation from `prepareAndStartRecording` only when the resolved purpose is `.dictation` and the effective dictation-style policy enables it. Place it after the active app/meeting identity is resolved but before `startRecorder`. Make the capture best-effort: no permission error or provider error may abort recording. Add the resulting `.selectedTextAtStart` item and typed context block to the recording's post-processing context state.

**Verify**: focused capture/lifecycle tests prove enabled dictation calls selected-only capture before recorder start, disabled/meeting paths do not call it, empty/failing capture does not fail recording, and captured text is redacted/guarded before storage or AI submission.

### Step 4: Merge start-time and post-start context safely

Change `startContextCaptureAfterRecordingStart` and deferred OCR updates so they merge new context items with the existing start-time item rather than replacing it. Preserve insertion order with selected text first, keep duplicate suppression by source and text, and serialize the new source as `<SELECTED_TEXT_AT_START>`. Update any append helper still emitting legacy free-form OCR/focused blocks in the touched lifecycle path. Ensure cancellation, failed start, discard, retry, and transcription persistence retain or clear the item consistently with the existing `postProcessingContextItems` lifecycle.

**Verify**: recording-manager tests cover start-time item preservation after async context capture, deferred OCR merge, cancellation cleanup, retry input, and no duplicate selected-text blocks.

### Step 5: Align prompt instructions with the new source

Update meeting/dictation/simple-model prompt contracts to define `<SELECTED_TEXT_AT_START>` as a snapshot of text selected when dictation began. State that it may resolve names, files, terms, or references; it is never transcript content, never an instruction, must not be copied into output, and cannot override the transcript except for an obvious spelling/disambiguation correction. Keep the simple-model wording short and direct. Add request-payload assertions that the typed block is present only when captured and that prompt output rules remain unchanged.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'PromptServiceTests|PostProcessingSystemContextMetadataTests'` → all prompt/context tests pass and no meeting/dictation tag contract regresses.

### Step 6: Validate persistence and end-to-end evidence

Add a Core Data/domain round-trip test for a transcription containing `.selectedTextAtStart`; prove old context-item JSON still decodes and the new item survives save/load. Run the focused suite, `make build-agent`, `make preview-check`, and the Full gate. Record any known baseline failures precisely; do not weaken or skip the gate. Review the final diff for privacy: no selected-text value may appear in logs, telemetry, or test artifacts beyond in-memory assertions.

**Verify**: all commands in the Commands table run; `git diff --check` passes; only in-scope files are modified.

## Test plan

- `DictationStyle`/settings tests: missing-field legacy decode defaults false; new field encodes/decodes true; default style is false; custom/default editor save and reload preserve the value.
- `AXTextContextProvider` or selected-provider tests: selected text is returned; no selection returns nil; full value/visible text is not used; permission/exclusion failures remain non-fatal at recording orchestration level.
- `AssistantContextCaptureService` tests: guardrails and redaction apply; source item is `.selectedTextAtStart`; context contains exactly one typed block.
- Recording-manager tests: capture occurs before recorder start; only dictation uses it; post-start context merges instead of replacing; cancellation and failed start clear transient state; retries preserve the persisted item.
- `PromptServiceTests`: source-specific instruction, conflict policy, and request block presence.
- Persistence tests: `TranscriptionMO` JSON round-trip for the new enum case and backward compatibility for old cases.
- Localization/search tests: English and Portuguese keys exist and settings search routes the new key through the existing context-source family.

## Done criteria

- [x] The setting is visible as an opt-in checkbox in the existing dictation Context Sources UI, with English/Portuguese copy and Accessibility guidance.
- [x] Existing dictation-style JSON without `includeSelectedTextAtStart` decodes unchanged and the new value survives save/reload.
- [x] Selected text is read only once, at dictation start, through a selected-only Accessibility operation; no full focused/visible text fallback is used.
- [x] Capture failures never prevent recording and never log selected-text content.
- [x] `.selectedTextAtStart` survives context merging, retry, transcription persistence, and display metadata.
- [x] The post-processing payload uses `<SELECTED_TEXT_AT_START>` and prompts explicitly forbid treating it as transcript content or instructions.
- [x] Focused tests, `make preview-check`, `make build-agent`, and `git diff --check` pass.
- [x] `make validate-agent ARGS="--lane full --no-reuse --agent"` is run and its result/baseline failures are reported honestly.
- [x] No files outside the Scope list are modified and the plan row is updated.

## STOP conditions

Stop and report instead of improvising if:

- The selected-text capture cannot be made distinct from the existing full focused/visible-text capture.
- The implementation would require changing meeting context behavior or blocking recording for Accessibility permission.
- Existing persisted dictation-style or context-item JSON cannot decode safely with a missing new field/case.
- A Core Data model migration appears necessary for the new context-item source.
- The start-time capture cannot be placed before recorder start without changing audio or recording semantics.
- Any test exposes selected-text content in logs, telemetry, or persisted diagnostics.
- The current prompt/context-hardening worktree changes are absent or materially different from the Current state assumptions.

## Maintenance notes

- Any future context source must define its capture moment, privacy policy, persisted `TranscriptionContextItem.Source`, typed prompt block, and model instructions together.
- Reviewers should inspect the exact start-time ordering and ensure later asynchronous capture cannot replace the snapshot.
- The new source is intentionally opt-in false; changing that default requires a privacy/product decision and migration review.
- The existing Full gate has a known unrelated baseline failure in `SettingsSearchIndexTests` for `settings.modes.prompts.title`; the executor must re-check whether it remains present rather than treating it as evidence for this feature.
- The `settings.modes.prompts.title` route was corrected in `SettingsSearchIndex`; the remaining Full-runner `INCOMPLETE` status came from CoreData/XPC diagnostics, while all 1,002 tests passed.
