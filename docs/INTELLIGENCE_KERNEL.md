# Reusable Intelligence Kernel

Last updated: 2026-02-22

## Objective

Provide a reusable intelligence-kernel abstraction used by Meeting mode now and extensible to Dictation and Assistant modes in future phases.

## Shared Contracts

The kernel contracts live in `MeetingAssistantCoreDomain`:

- `IntelligenceKernelMode`
- `IntelligenceKernelPostProcessingRequest`
- `IntelligenceKernelPostProcessingResult`
- `IntelligenceKernelQuestionRequest`
- `IntelligenceKernelValidationResult`

These contracts are mode-aware and intentionally decouple mode selection from implementation details.

## Meeting Mode (Current Active Mode)

Meeting mode is enabled and routed through shared contracts:

- Post-processing path:
  - `RecordingManager.makeUseCaseConfig(...)` gates execution via `AppSettingsStore.isIntelligenceKernelModeEnabled(.meeting)`.
  - `TranscribeAudioUseCase` continues to reuse the hardened canonical pipeline (`processTranscriptionStructured`).
- Grounded Q&A path:
  - `IntelligenceKernelServiceProtocol.ask(_ request: IntelligenceKernelQuestionRequest)`.
  - `MeetingQAService` is the current Meeting-mode implementation.

## Extension Points

To add Dictation or Assistant modes later, implement these extension points without changing caller contracts:

1. Enable mode flag in `FeatureFlags` (`enableDictationIntelligenceMode` or `enableAssistantIntelligenceMode`).
2. Add mode-specific routing inside kernel implementations (`MeetingQAService` or dedicated mode service).
3. Keep call sites using shared request contracts and `IntelligenceKernelMode`.
4. Reuse canonical summary trust metadata (`CanonicalSummary.trustFlags`) for validation semantics.

## Feature Flags Strategy

Kernel rollout is controlled by static flags in `FeatureFlags`:

- `enableIntelligenceKernel`
- `enableMeetingIntelligenceMode`
- `enableDictationIntelligenceMode`
- `enableAssistantIntelligenceMode`

`AppSettingsStore` is the policy adapter exposing:

- `intelligenceKernelEnabled`
- `isIntelligenceKernelModeEnabled(_ mode: IntelligenceKernelMode)`

This keeps mode activation centralized and explicit while preserving existing user settings (`postProcessingEnabled`, `meetingQnAEnabled`) as runtime capability toggles.
