# Modularization triage report

Generated: 2026-07-12T21:46:39-03:00
Worktree: `/Users/usuario/Documents/Projects/prisma`
Log: `/tmp/ma-agent/build-debug.log`

## Summary

- Swift files scanned: **486**
- Files with compiler findings in log: **2**
- Files with suggested import fixes: **106**
- Files with non-English comment candidates: **66** (heuristic)

## Compiler findings (from log)

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsAudioAndAIConfiguration.swift`

- L298:5 `warning`: 'public' modifier is redundant for property declared in a public extension
- L298:5 `warning`: 'public' modifier is redundant for property declared in a public extension

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/AIModeSelection.swift`

- L473:20 `warning`: value 'siblingIssue' was defined but never used; consider replacing with boolean test

## Suggested module imports (heuristic)

- `Packages/MeetingAssistantCore/Sources/AI/Infrastructure/Providers/AIProviderProtocol.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/AI/Services/CohereTranscribeModelRuntime.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/AI/Services/FluidAIModelManager.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/AI/Services/FluidAudioProvider.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/LegacyAPI.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/Networking.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/Pipelines.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/PostProcessingService.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/StructuredAPI.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/TracingAndValidation.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionDeliveryService.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionProvider.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/AI/Services/XPC/MeetingAssistantXPCProtocol.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels/AudioKernelProvider.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioLevelMonitor.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioMerger.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/AudioRecorder.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon, MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/AudioRecorderOutputInterruption.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/Diagnostics.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/EngineSetup.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/InputDeviceSelection.swift` → `MeetingAssistantCoreCommon, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/Validation.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecordingWorker.swift` → `MeetingAssistantCoreCommon, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioSilenceCompactor.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Common/Config/FeatureFlags.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/Common/Logging/AppLogger.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/Common/Logging/LogCategory.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Common/Logging/ShortcutTelemetry.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/Common/Security/InputSanitizer.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/Core/MeetingAssistantCore.docc/Resources/code/getting-started-1.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/AudioFileRepositoryAdapter.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/PostProcessingRepositoryAdapter.swift` → `MeetingAssistantCoreAI, MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/TranscriptionRepositoryAdapter.swift` → `MeetingAssistantCoreAI, MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Entities/MeetingEntity.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/PostProcessing.swift` → `MeetingAssistantCoreCommon, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/TranscribeAudioUseCase.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/AIPromptTemplates.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/CapturePurpose.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/IntelligenceKernel.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/Meeting.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/MeetingQA.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/MeetingState.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/PermissionStatus.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/PostProcessingPrompt.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/RecordingSource.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/Transcription.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/TranscriptionMetadata.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/VocabularyReplaceableSegment.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Domain/Utilities/MetricsAggregator.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsAudioAndAIConfiguration.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/AIModeSelection.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/AppSettings.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/AssistantIntegrations.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/CalendarEvents.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/ComputedProperties.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/ContextWebTargets.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/DefaultShortcuts.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/Defaults.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/DefaultsReset.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/GeneralSettings.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/Initialization.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/Keys.swift` → `MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/LoadingHelpers.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/ModelResidencyTimeoutOption.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/PersistenceHelpers.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/PromptManagement.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/TranscriptionModeSelection.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/VocabularyRulesNormalization.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/ModelPerformanceIdentity.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/AXCursorTextContextProvider.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/AXTextContextProvider.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/AccessibilityPermissionService.swift` → `MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/CaptureContextResolver.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/ContextAwarenessService.swift` → `MeetingAssistantCoreCommon, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/PasteboardService.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/Protocols.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/TextContextSupportChecker.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/UI/Models/MenuBarRecordingSectionState.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Presentation/MeetingNotesFloatingPanelController.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/Presentation/RecordingIndicatorRenderState.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/AssistantTextSelectionService.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/Export.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalDictationTranscriptionCoordinator.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalMeetingTranscriptionCoordinator.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalTranscriptionCoordinatorCore.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/MeetingNotes.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/PostProcessing.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/PostProcessingPipeline.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingControl.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerAutomaticMeetingRecording.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerCalendarIntegration.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerContextCapture.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerImport.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerTranscriptionEntities.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerTranscriptionExecution.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerTranscriptionPipeline.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerTranscriptionProgress.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/Retry.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/OnboardingViewModel.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSModifierShortcutEditor.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingMeetingRecordingView.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingTypes.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/MeetingNotesMarkdownEditor.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/MeetingNotesRichTextEditor.swift` → `MeetingAssistantCoreDomain`

## Static-scan candidates

These files reference known cross-module symbols but do not import any of the mapped modules.

- `Packages/MeetingAssistantCore/Sources/AI/Infrastructure/Providers/AIProviderProtocol.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/CohereTranscribeModelRuntime.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/FluidAIModelManager.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionProvider.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioKernels/AudioKernelProvider.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioLevelMonitor.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioMerger.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/AudioRecorder.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/AudioRecorderOutputInterruption.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/Diagnostics.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/EngineSetup.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/InputDeviceSelection.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/Validation.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecordingWorker.swift`
- `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioSilenceCompactor.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Config/FeatureFlags.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Logging/AppLogger.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Logging/LogCategory.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Logging/ShortcutTelemetry.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Security/InputSanitizer.swift`
- `Packages/MeetingAssistantCore/Sources/Core/MeetingAssistantCore.docc/Resources/code/getting-started-1.swift`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/AudioFileRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/PostProcessingRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/TranscriptionRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Entities/MeetingEntity.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/PostProcessing.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/TranscribeAudioUseCase.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/AIPromptTemplates.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/IntelligenceKernel.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/MeetingQA.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/MeetingState.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/Transcription.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/TranscriptionMetadata.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/VocabularyReplaceableSegment.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Utilities/MetricsAggregator.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/CalendarEvents.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/DefaultShortcuts.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/GeneralSettings.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/Keys.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/LoadingHelpers.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/PersistenceHelpers.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/TranscriptionModeSelection.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/AXCursorTextContextProvider.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/AXTextContextProvider.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/AccessibilityPermissionService.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/ContextAwarenessService.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/PasteboardService.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/TextContextSupportChecker.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/AssistantTextSelectionService.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalDictationTranscriptionCoordinator.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalMeetingTranscriptionCoordinator.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalTranscriptionCoordinatorCore.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingMeetingRecordingView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingTypes.swift`

## Current-main classification

- The historical `MAThemePicker` compiler finding is not reproducible: the symbol and file are absent from current source.
- The build log contains two existing warnings only (`public` in a public extension and an unused `siblingIssue` binding); neither is an import or module-boundary failure.
- `make arch-check` passed. The current build-agent result also passed, so no missing import is confirmed by the compiler.
- The 106 suggested import entries and static candidates are heuristic false positives for this run. The scanner reports symbols declared in the same module, files that intentionally rely on re-exported module surfaces, and self-module references; it is not evidence for adding imports. No source import change is justified.
- The 66 non-English comment candidates are also heuristic. Many match `para` inside English words such as `parameter`, and the remaining Portuguese comments are broad legacy documentation rather than a current modularization defect. No translation is made under this plan's narrow scope; broad comment cleanup remains deferred.

Conclusion: plan 051 produces a current report and reclassifies the historical issue, but has no confirmed import or comment hygiene change to implement.

## Non-English comment candidates (heuristic)

### `Packages/MeetingAssistantCore/Sources/AI/Services/CohereTranscribeModelRuntime.swift`

- L193: // portable .mlpackage exports; forcing ANE at first load can

### `Packages/MeetingAssistantCore/Sources/AI/Services/Export/ExportService.swift`

- L4: /// Service responsible for exporting meeting data to files.
- L12: /// Exports the meeting and transcription to a file at the specified URL.
- L13: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/AI/Services/FluidAIModelManager.swift`

- L198: /// Public version without parameters for protocol conformance.

### `Packages/MeetingAssistantCore/Sources/AI/Services/FluidAudio/Sendable.swift`

- L6: /// FluidAudio checkouts are patched before supported builds/tests so

### `Packages/MeetingAssistantCore/Sources/AI/Services/FluidAudioProvider.swift`

- L37: // MARK: - Preparation
- L40: /// - Parameter progressHandler: Optional callback for download progress (0.0 to 1.0)
- L67: /// - Parameter samples: 16kHz mono PCM float samples

### `Packages/MeetingAssistantCore/Sources/AI/Services/LocalTranscriptionClient.swift`

- L32: /// - Parameter audioURL: Path to the audio file.
- L33: /// - Parameter onProgress: Optional callback for transcription progress.

### `Packages/MeetingAssistantCore/Sources/AI/Services/Output/MarkdownRenderer.swift`

- L9: /// - Parameters:
- L70: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/LegacyAPI.swift`

- L11: /// - Parameter transcription: The raw transcription text.
- L27: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/AI/Services/PromptService.swift`

- L11: /// - Parameter type: The type of meeting.

### `Packages/MeetingAssistantCore/Sources/AI/Services/Prompting/PromptStrategy.swift`

- L10: /// - Parameter transcription: The raw text of the meeting transcription.

### `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionProvider.swift`

- L41: /// - Parameter progressHandler: Optional callback for download progress (0.0 to 1.0)
- L45: /// - Parameter samples: 16kHz mono PCM float samples
- L50: /// - Parameter audioURL: Path to the audio file

### `Packages/MeetingAssistantCore/Sources/AI/Services/XPC/MeetingAssistantXPCProtocol.swift`

- L10: /// - Parameters:
- L21: /// - Parameter reply: Callback with JSON encoded `MeetingAssistantXPCModels.ServiceStatus` or error.
- L25: /// - Parameter reply: Callback indicating success or error.

### `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioBufferQueue.swift`

- L26: /// - Parameter capacity: Maximum number of buffers to hold. Default is 50 (~5-10s depending on buffer size).

### `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioDeviceManager.swift`

- L437: /// Used to capture the original default before temporarily overriding it.
- L442: /// Temporarily sets the system default input device.

### `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioLevelMonitor.swift`

- L89: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioMerger.swift`

- L18: /// - Parameters:
- L69: // Export using AVAssetWriter
- L226: /// This is safe because these objects are accessed exclusively within the serial export queue.

### `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/AudioRecorder.swift`

- L217: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/InputDeviceSelection.swift`

- L16: /// Applies the preferred custom microphone by temporarily overriding the system

### `Packages/MeetingAssistantCore/Sources/Audio/Services/AudioRecorder/SourceNode.swift`

- L10: /// - Parameters:
- L29: /// - Parameters:
- L52: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/Audio/Services/PartialBufferState.swift`

- L43: /// - Parameters:
- L57: /// - Parameters:
- L135: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/Audio/Services/SystemAudioMuteController.swift`

- L36: /// - Parameter muted: True to mute, false to unmute.

### `Packages/MeetingAssistantCore/Sources/Common/Utils/TimeFormatter.swift`

- L6: /// - Parameter seconds: Time interval in seconds
- L23: /// - Parameter seconds: Time interval in seconds

### `Packages/MeetingAssistantCore/Sources/Core/Exports.swift`

- L1: // Re-export internal modules so app code can continue to `import MeetingAssistantCore`.
- L17: // Re-export shortcut input types for convenience

### `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/CoreDataModel.swift`

- L3: // CoreDataModel - Definição programática do modelo CoreData
- L4: // Permite versionamento e migração automática seguindo Clean Architecture
- L9: /// Configuração programática do modelo CoreData

### `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/CoreDataStack.swift`

- L4: // CoreDataStack - Stack thread-safe para gerenciamento de CoreData
- L11: /// Stack CoreData thread-safe com suporte a operações em background
- L24: /// Contexto principal para operações na main thread

### `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/MeetingMO.swift`

- L3: // MeetingMO - Managed Object para MeetingEntity
- L9: /// Managed Object para entidade Meeting
- L30: /// Fetch request para buscar todas as reuniões ordenadas por data

### `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/TranscriptionMO.swift`

- L3: // TranscriptionMO - Managed Object para TranscriptionEntity
- L11: /// Managed Object para entidade Transcription
- L58: /// Fetch request para buscar todas as transcrições ordenadas por data

### `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/TranscriptionSegmentMO.swift`

- L3: // TranscriptionSegmentMO - Managed Object para segmentos de transcrição
- L9: /// Managed Object para segmentos de transcrição
- L25: /// Fetch request para buscar segmentos de uma transcrição

### `Packages/MeetingAssistantCore/Sources/Data/Data/Repositories/CoreDataMeetingRepository.swift`

- L3: // CoreDataMeetingRepository - Implementação de MeetingRepository usando CoreData
- L4: // Thread-safe e isolado do domínio
- L9: /// Repositório de reuniões usando CoreData para persistência

### `Packages/MeetingAssistantCore/Sources/Data/Data/Repositories/CoreDataTranscriptionStorageRepository.swift`

- L3: // CoreDataTranscriptionStorageRepository - Implementação de TranscriptionStorageRepository usando CoreData
- L4: // Thread-safe e isolado do domínio
- L9: /// Repositório de transcrições usando CoreData para persistência

### `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/AudioFileRepositoryAdapter.swift`

- L1: // AudioFileRepositoryAdapter - Adapter para AudioFileRepository usando FileSystemStorageService
- L28: // Criar uma Meeting temporária para compatibilidade com createRecordingURL

### `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/MeetingRepositoryAdapter.swift`

- L1: // MeetingRepositoryAdapter - Adapter para MeetingRepository usando FileSystemStorageService
- L8: /// Nota: Como o StorageService atual não armazena reuniões separadamente,
- L9: /// este adapter mantém reuniões em memória para compatibilidade

### `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/PostProcessingRepositoryAdapter.swift`

- L1: // PostProcessingRepositoryAdapter - Adapter para PostProcessingRepository usando PostProcessingService
- L43: // Converter DomainPostProcessingPrompt para PostProcessingPrompt (legado)

### `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/TranscriptionRepositoryAdapter.swift`

- L1: // TranscriptionRepositoryAdapter - Adapter para TranscriptionRepository usando TranscriptionClient

### `Packages/MeetingAssistantCore/Sources/Domain/Domain/Entities/MeetingEntity.swift`

- L1: // MeetingEntity - Domain Entity pura sem dependências de UI/frameworks
- L6: /// Representa um aplicativo de reunião que pode ser detectado.
- L18: /// Bundle identifiers para detectar este app.

### `Packages/MeetingAssistantCore/Sources/Domain/Domain/Entities/TranscriptionEntity.swift`

- L1: // TranscriptionEntity - Domain Entity pura sem dependências de UI/frameworks
- L5: /// Representa uma transcrição completada.
- L14: /// Segmentos da transcrição com identificação de speaker.

### `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift`

- L1: // Domain Protocols - Interfaces para infraestrutura seguindo Clean Architecture
- L11: // Protocolo para operações de gravação de áudio
- L16: /// Inicia gravação para URL especificada

### `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/ImportAudioUseCase.swift`

- L1: // ImportAudioUseCase - Caso de uso para importar arquivo de áudio
- L5: /// Caso de uso para importar arquivo de áudio externo
- L10: /// Inicializa o caso de uso com dependências

### `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/StartRecordingUseCase.swift`

- L1: // StartRecordingUseCase - Caso de uso para iniciar gravação
- L5: /// Caso de uso para iniciar gravação de reunião
- L11: /// Inicializa o caso de uso com dependências

### `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/StopRecordingUseCase.swift`

- L1: // StopRecordingUseCase - Caso de uso para parar gravação
- L5: /// Caso de uso para parar gravação de reunião
- L10: /// Inicializa o caso de uso com dependências

### `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/TranscribeAudioUseCase.swift`

- L1: // TranscribeAudioUseCase - Caso de uso para transcrever áudio
- L6: /// Caso de uso para transcrever arquivo de áudio
- L34: /// Inicializa o caso de uso com dependências

### `Packages/MeetingAssistantCore/Sources/Domain/Models/AIPromptTemplates.swift`

- L108: /// - Parameters:
- L141: /// - Parameter modelName: The model identifier from the AI configuration.
- L215: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/Domain/Models/IntelligenceKernel.swift`

- L3: /// Supported execution modes for the shared intelligence kernel.

### `Packages/MeetingAssistantCore/Sources/Domain/Models/Transcription.swift`

- L58: /// Full initializer with post-processing support.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Infrastructure/CrashReporter.swift`

- L5: /// Manages crash reporting and logging of uncaught exceptions to disk
- L28: // We rely on macOS system crash reporter for signals (SIGSEGV, SIGABRT)

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Infrastructure/PerformanceMonitor.swift`

- L6: /// Monitors application performance and reports metrics
- L58: /// Report a specific metric event immediately

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsCoreConfiguration.swift`

- L9: /// Supported AI providers for post-processing transcriptions.
- L60: /// Supported app languages for UI localization.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/AppSettings.swift`

- L303: /// Whether silence should be removed from a temporary audio copy before transcription.
- L335: /// Breaks long dictated text into paragraphs before delivery.
- L481: /// Path URL for exporting summaries.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/GeneralSettings.swift`

- L36: /// If empty or invalid, services should fallback to the default Application Support directory.
- L97: /// Supported audio formats for recording.
- L150: // Moved to main class body to support @Published storage

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/Initialization.swift`

- L8: /// Holds temporarily loaded values during initialization to avoid multiple UserDefaults reads.
- L632: /// Struct for resolving shortcut definitions to avoid excessive parameters.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/PromptManagement.swift`

- L7: /// - Parameter prompt: The prompt to add.
- L14: /// - Parameter prompt: The prompt with updated values.
- L26: /// - Parameter id: The ID of the prompt to delete.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/ModifierShortcutGesture.swift`

- L3: /// Modifier keys supported by the hybrid shortcut engine.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/KeychainManager.swift`

- L475: /// - Parameters:
- L488: /// - Parameter key: The key to retrieve the value for.
- L516: /// - Parameter key: The key to delete.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/MeetingDetector.swift`

- L8: /// Service for detecting active meetings from supported apps.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/ShortcutInputEvent/NSEvent.swift`

- L23: // that do not support key-event accessors like isARepeat.

### `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/UpdateService.swift`

- L6: /// Keeps all Sparkle imports contained in a single file to avoid framework leakage

### `Packages/MeetingAssistantCore/Sources/UI/Presentation/FloatingRecordingIndicatorController.swift`

- L83: /// - Parameters:
- L106: /// - Parameter mode: Whether to present recording or processing visuals.

### `Packages/MeetingAssistantCore/Sources/UI/Presentation/PresentationProtocols.swift`

- L11: /// Protocolo base para objetos que podem apresentar views
- L20: /// Protocolo para objetos que coordenam navegação
- L32: /// Navega para uma rota específica

### `Packages/MeetingAssistantCore/Sources/UI/Services/AssistantContextCaptureService.swift`

- L111: // swiftlint:disable:next function_parameter_count

### `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/Export.swift`

- L7: // MARK: - Summary Export
- L10: /// Export summary to configured folder with safety checks.

### `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerImport.swift`

- L11: /// - Parameter audioURL: Path to the audio file (m4a, mp3, wav).

### `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift`

- L31: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/Retry.swift`

- L11: /// - Parameter transcription: Existing transcription to overwrite with new results.
- L12: /// - Parameter selectionOverride: Optional provider/model override for this retry.

### `Packages/MeetingAssistantCore/Sources/UI/ViewModels/MeetingSettingsViewModel.swift`

- L111: // MARK: - Export Configuration

### `Packages/MeetingAssistantCore/Sources/UI/ViewModels/RecordingViewModel.swift`

- L126: /// Import and transcribe an external audio file.
- L127: /// - Parameter url: Path to the audio file (m4a, mp3, wav).

### `Packages/MeetingAssistantCore/Sources/UI/components/shared/TranscribeFileButton.swift`

- L10: /// Button component that opens a file picker for importing audio files to transcribe.
