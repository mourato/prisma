# Assistant automation-rule spike — 2026-07-12

## Decision

Do not build a general automation engine in this spike. The recommended next slice is a one-shot, user-initiated voice rule that routes an Assistant command to an existing saved integration. It must remain opt-in and bounded to the current Assistant workflow.

Continuous app monitoring, automatic recording triggers, arbitrary shell execution, user-authored deep-link URLs, CloudKit synchronization, and a user-facing rule editor are deferred.

## MVP boundary

The MVP may contain:

- a rule enabled/disabled flag;
- a deterministic voice-phrase matcher over the normalized Assistant transcription;
- an optional existing execution-flow constraint (`assistantMode` or `integrationDispatch`);
- one action: route to an existing, enabled `AssistantIntegrationConfig` by ID;
- one winning rule per command.

The MVP does not contain app-bundle conditions. The current pipeline does not carry a stable active-app identity through the evaluation boundary; adding one would require a separate read-only context contract. App conditions can be a follow-up after that contract is designed and tested.

Rules run only after an explicit Assistant recording has been started through the existing shortcut/command path. There is no background microphone listener and no automatic recording start. When automation is disabled or no rule matches, the current Assistant behavior remains unchanged.

## Conceptual vocabulary

```text
AutomationRule
  id: stable identifier
  enabled: Bool
  priority: Int
  trigger: voicePhrase(String, matchMode)
  condition: executionFlow?
  action: routeToIntegration(integrationID)
```

The first implementation should keep these values as an in-memory/pure evaluator model. Persistence, migration, settings UI, import/export, and sync require a separate product decision and are not part of this spike.

Phrase matching must be deterministic and local: normalize whitespace/case, apply the existing vocabulary replacement rules first, and support an explicit match mode such as exact phrase or prefix. Do not use a second LLM call to decide whether a rule matches.

## Architecture fit

The design reuses the current boundaries:

1. `AssistantVoiceCommandService` remains the lifecycle owner for recording, processing, cancellation, indicator state, and error presentation.
2. `AssistantRecordingOrchestrator` remains the only Assistant recording start/stop/cancel path and continues to use `RecordingExclusivityCoordinator`.
3. `AssistantTranscriptionPhase` remains responsible for vocabulary normalization and command extraction.
4. A future pure evaluator can receive the normalized command, execution flow, and enabled rule values. It must not access audio, Core Data, UserDefaults, Keychain, AppKit, or the network.
5. A matched integration is resolved through the existing `AppSettingsStore.assistantIntegrations` state and then passed through `AssistantAIPhase` and `AssistantDispatchPhase`.
6. `AssistantRaycastIntegrationService` remains the only deep-link dispatcher. `AssistantTextSelectionService` remains the only selected-text capture/replacement path.
7. `AssistantBashScriptRunner` is deliberately not an automation action. Existing integration scripts are a separate, explicit integration feature and must not become ambient rule execution.

No second recording pipeline, provider-selection path, credential path, or dispatch abstraction is justified.

## Deterministic conflict policy

The evaluator should:

1. ignore disabled rules;
2. discard rules whose execution-flow condition does not match;
3. discard rules whose integration ID is missing, disabled, or no longer registered;
4. rank remaining rules by priority descending, then phrase specificity descending (exact before prefix), then stable ID ascending;
5. return one winner and a diagnostic reason, or no match;
6. never execute a fallback chain of multiple actions.

If two rules remain indistinguishable after the stable-ID tie-break, the evaluator should report a configuration conflict and return no action. The future editor should prevent that state, but runtime safety must not depend on editor validation.

## Safety and privacy model

- Automation is off by default and only runs inside an explicit user-started Assistant session.
- Actions are an allowlist of existing integration IDs. No arbitrary command, URL, script, file path, credential, or provider endpoint is stored in a rule.
- External dispatch must preserve the existing validated deep-link and integration-enabled checks.
- Selected-text replacement remains subject to the existing Accessibility permission and pasteboard restoration path.
- A future action that mutates selected text or dispatches externally should offer a confirmation/preview policy before silent execution is enabled. The first MVP can keep integration routing visible through the existing processing indicator and result path.
- Logs contain rule ID, match mode, execution flow, and outcome only. Do not log the voice command, selected text, prompt, API key, or deep-link payload.
- Cancellation, recording exclusivity, Keychain use, and local persistence remain owned by their existing services.

## Open decisions before implementation

- Whether the product wants phrase matching before or after the Assistant AI rewrite. Recommendation: match the normalized transcription before AI, so trigger selection is deterministic; use the selected integration in the existing AI/dispatch phases afterward.
- Whether a matched rule should require confirmation on every run or only for specific action classes.
- Whether rules should be persisted in UserDefaults as a small versioned collection or receive a dedicated repository. Do not choose until the MVP proves the vocabulary and conflict model.
- Whether app-bundle conditions justify a new read-only `ActiveAppContext` input at the phase boundary.

## Review conclusion

The spike is architecture-compatible only as a pure, one-shot routing decision inside the existing Assistant phases. A general automation engine would duplicate lifecycle/dispatch behavior and introduce unsafe ambient execution. Issue #91 should remain open and move to implementation only after the open product decisions above are resolved.
