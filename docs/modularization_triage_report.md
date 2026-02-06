# Modularization triage report

Generated: 2026-02-06T16:12:02-03:00
Worktree: `/Users/usuario/Documents/Repos/my-meeting-assistant/codex-arch-review-2026-02-06`
Log: `/tmp/test-output.log`

## Summary

- Swift files scanned: **180**
- Files with compiler findings in log: **1**
- Files with suggested import fixes: **69**
- Files with non-English comment candidates: **59** (heuristic)

## Compiler findings (from log)

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/DesignSystem/Components/MAThemePicker.swift`

- L4:37 `error`: cannot find type 'AppThemeColor' in scope
- L6:36 `error`: cannot find type 'AppThemeColor' in scope
- L19:39 `error`: cannot find type 'AppThemeColor' in scope
- L12:21 `error`: cannot find 'AppThemeColor' in scope
- L12:13 `error`: generic parameter 'C' could not be inferred

## Suggested module imports (heuristic)

- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/MeetingAssistantCore.docc/Resources/code/getting-started-1.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Infrastructure/Providers/AIProviderProtocol.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/FluidAIModelManager.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/FluidAudioProvider.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/PostProcessingService.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/TranscriptionClient.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/TranscriptionProvider.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/XPC/MeetingAssistantXPCProtocol.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioLevelMonitor.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder+Diagnostics.swift` → `MeetingAssistantCoreCommon, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder+Validation.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon, MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecordingWorker.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Config/FeatureFlags.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Logging/AppLogger.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Logging/LogCategory.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreCommon, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Security/InputSanitizer.swift` → `MeetingAssistantCoreCommon`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/AudioFileRepositoryAdapter.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/PostProcessingRepositoryAdapter.swift` → `MeetingAssistantCoreAI, MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/TranscriptionRepositoryAdapter.swift` → `MeetingAssistantCoreAI, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/TranscriptionStorageRepositoryAdapter.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/Entities/MeetingEntity.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/Interfaces/DomainProtocols.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/Meeting.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/MeetingState.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/PermissionStatus.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/PostProcessingPrompt.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/RecordingSource.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/Transcription.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Models/AppSettings.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Services/AccessibilityPermissionService.swift` → `MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Services/PasteboardService.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Services/Protocols.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/AssistantScreenBorderController.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/Coordinators/AppCoordinator.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/Coordinators/SettingsCoordinator.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/FloatingRecordingIndicatorController.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/PresentationProtocols.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Services/AssistantTextSelectionService.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Services/AssistantVoiceCommandService.swift` → `MeetingAssistantCoreAI, MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Services/RecordingServiceProtocol.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/AISettingsViewModel.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/AssistantShortcutSettingsViewModel.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/DictationPromptSettingsViewModel.swift` → `MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/GeneralSettingsViewModel.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/MeetingSettingsViewModel.swift` → `MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/PermissionViewModel.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/PostProcessingSettingsViewModel.swift` → `MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/RecordingViewModel.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/ServiceSettingsViewModel.swift` → `MeetingAssistantCoreAI`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/ShortcutSettingsViewModel.swift` → `MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/TranscriptionImportViewModel.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/TranscriptionSettingsViewModel.swift` → `MeetingAssistantCoreAI, MeetingAssistantCoreAudio, MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Components/RecordingButton.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Components/TranscriptionCardView.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Components/TranscriptionInfoPopover.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/MenuBarView.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/PermissionStatusView.swift` → `MeetingAssistantCoreAudio, MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Components/PromptEditorSheet.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Components/SpeakerIdentificationSettingsSection.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/SettingsView.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/AudioSettingsTab.swift` → `MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/DictationSettingsTab.swift` → `MeetingAssistantCoreDomain, MeetingAssistantCoreInfrastructure`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/MeetingSettingsTab.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/PermissionsSettingsTab.swift` → `MeetingAssistantCoreAudio`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/PostProcessingSettingsTab.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/TranscriptionsSettingsTab.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/TranscriptionDetailView.swift` → `MeetingAssistantCoreDomain`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/TranscribeFileButton.swift` → `MeetingAssistantCoreAudio`

## Static-scan candidates

These files reference known cross-module symbols but do not import any of the mapped modules.

- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/MeetingAssistantCore.docc/Resources/code/getting-started-1.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Infrastructure/Providers/AIProviderProtocol.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/FluidAIModelManager.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/FluidAudioProvider.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/TranscriptionProvider.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/XPC/MeetingAssistantXPCProtocol.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioLevelMonitor.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder+Diagnostics.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder+Validation.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecordingWorker.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Config/FeatureFlags.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Logging/AppLogger.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Logging/LogCategory.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Security/InputSanitizer.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/AudioFileRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/PostProcessingRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/TranscriptionRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/TranscriptionStorageRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/Entities/MeetingEntity.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/Interfaces/DomainProtocols.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/MeetingState.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/Transcription.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Services/AccessibilityPermissionService.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Services/PasteboardService.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/AssistantScreenBorderController.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/Coordinators/AppCoordinator.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/Coordinators/SettingsCoordinator.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/FloatingRecordingIndicatorController.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/PresentationProtocols.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Services/AssistantTextSelectionService.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/AISettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/AssistantShortcutSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/DictationPromptSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/GeneralSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/MeetingSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/PermissionViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/PostProcessingSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/RecordingViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/ServiceSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/ShortcutSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/TranscriptionImportViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/TranscriptionSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Components/RecordingButton.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Components/TranscriptionCardView.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Components/TranscriptionInfoPopover.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/MenuBarView.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/PermissionStatusView.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Components/PromptEditorSheet.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Components/SpeakerIdentificationSettingsSection.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/SettingsView.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/AudioSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/DictationSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/MeetingSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/PermissionsSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/PostProcessingSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/TranscriptionsSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/TranscriptionDetailView.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/TranscribeFileButton.swift`

## Non-English comment candidates (heuristic)

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Exports.swift`

- L1: // Re-export internal modules so app code can continue to `import MeetingAssistantCore`.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/Export/ExportService.swift`

- L4: /// Service responsible for exporting meeting data to files.
- L12: /// Exports the meeting and transcription to a file at the specified URL.
- L13: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/FluidAIModelManager.swift`

- L142: /// Public version without parameters for protocol conformance.
- L307: // If specific constraints provided, update manager config (assuming it supports it at runtime or we recreate)

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/FluidAudioProvider.swift`

- L35: // MARK: - Preparation
- L38: /// - Parameter progressHandler: Optional callback for download progress (0.0 to 1.0)
- L65: /// - Parameter samples: 16kHz mono PCM float samples

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/LocalTranscriptionClient.swift`

- L22: /// - Parameter audioURL: Path to the audio file.
- L23: /// - Parameter onProgress: Optional callback for transcription progress.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/Output/MarkdownRenderer.swift`

- L9: /// - Parameters:
- L60: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/PostProcessingService.swift`

- L41: /// - Parameter transcription: The raw transcription text.
- L57: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/PromptService.swift`

- L11: /// - Parameter type: The type of meeting.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/Prompting/PromptStrategy.swift`

- L10: /// - Parameter transcription: The raw text of the meeting transcription.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/TranscriptionDeliveryService.swift`

- L17: // Meeting recordings and imported files should not trigger this.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/TranscriptionProvider.swift`

- L41: /// - Parameter progressHandler: Optional callback for download progress (0.0 to 1.0)
- L45: /// - Parameter samples: 16kHz mono PCM float samples
- L50: /// - Parameter audioURL: Path to the audio file

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAI/Services/XPC/MeetingAssistantXPCProtocol.swift`

- L9: /// - Parameters:
- L20: /// - Parameter reply: Callback with JSON encoded `MeetingAssistantXPCModels.ServiceStatus` or error.
- L24: /// - Parameter reply: Callback indicating success or error.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioBufferQueue.swift`

- L25: /// - Parameter capacity: Maximum number of buffers to hold. Default is 50 (~5-10s depending on buffer size).

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioLevelMonitor.swift`

- L48: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioMerger.swift`

- L17: /// - Parameters:
- L68: // Export using AVAssetWriter
- L225: /// This is safe because these objects are accessed exclusively within the serial export queue.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder+SourceNode.swift`

- L9: /// - Parameters:
- L28: /// - Parameters:
- L51: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/AudioRecorder.swift`

- L120: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/PartialBufferState.swift`

- L42: /// - Parameters:
- L53: /// - Parameters:
- L127: /// - Parameters:

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreAudio/Services/SystemAudioMuteController.swift`

- L12: /// - Parameter muted: True to mute, false to unmute.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreCommon/Utils/TimeFormatter.swift`

- L6: /// - Parameter seconds: Time interval in seconds
- L23: /// - Parameter seconds: Time interval in seconds

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Data/CoreData/CoreDataModel.swift`

- L2: // CoreDataModel - Definição programática do modelo CoreData
- L3: // Permite versionamento e migração automática seguindo Clean Architecture
- L8: /// Configuração programática do modelo CoreData

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Data/CoreData/CoreDataStack.swift`

- L2: // CoreDataStack - Stack thread-safe para gerenciamento de CoreData
- L9: /// Stack CoreData thread-safe com suporte a operações em background
- L16: /// Contexto principal para operações na main thread

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Data/CoreData/MeetingMO.swift`

- L2: // MeetingMO - Managed Object para MeetingEntity
- L8: /// Managed Object para entidade Meeting
- L24: /// Fetch request para buscar todas as reuniões ordenadas por data

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Data/CoreData/TranscriptionMO.swift`

- L2: // TranscriptionMO - Managed Object para TranscriptionEntity
- L10: /// Managed Object para entidade Transcription
- L37: /// Fetch request para buscar todas as transcrições ordenadas por data

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Data/CoreData/TranscriptionSegmentMO.swift`

- L2: // TranscriptionSegmentMO - Managed Object para segmentos de transcrição
- L8: /// Managed Object para segmentos de transcrição
- L24: /// Fetch request para buscar segmentos de uma transcrição

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Data/Repositories/CoreDataMeetingRepository.swift`

- L2: // CoreDataMeetingRepository - Implementação de MeetingRepository usando CoreData
- L3: // Thread-safe e isolado do domínio
- L8: /// Repositório de reuniões usando CoreData para persistência

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Data/Repositories/CoreDataTranscriptionStorageRepository.swift`

- L2: // CoreDataTranscriptionStorageRepository - Implementação de TranscriptionStorageRepository usando CoreData
- L3: // Thread-safe e isolado do domínio
- L8: /// Repositório de transcrições usando CoreData para persistência

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Data/Repositories/HybridTranscriptionStorageRepository.swift`

- L2: // HybridTranscriptionStorageRepository - Implementação híbrida para migração gradual
- L3: // Lê de JSON (legado) e CoreData (novo), mas escreve apenas em CoreData
- L7: /// Repositório híbrido que suporta leitura de dados legados em JSON

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/AudioFileRepositoryAdapter.swift`

- L1: // AudioFileRepositoryAdapter - Adapter para AudioFileRepository usando FileSystemStorageService
- L28: // Criar uma Meeting temporária para compatibilidade com createRecordingURL

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/MeetingRepositoryAdapter.swift`

- L1: // MeetingRepositoryAdapter - Adapter para MeetingRepository usando FileSystemStorageService
- L8: /// Nota: Como o StorageService atual não armazena reuniões separadamente,
- L9: /// este adapter mantém reuniões em memória para compatibilidade

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/PostProcessingRepositoryAdapter.swift`

- L1: // PostProcessingRepositoryAdapter - Adapter para PostProcessingRepository usando PostProcessingService
- L25: // Converter DomainPostProcessingPrompt para PostProcessingPrompt (legado)

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/TranscriptionRepositoryAdapter.swift`

- L1: // TranscriptionRepositoryAdapter - Adapter para TranscriptionRepository usando TranscriptionClient

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/Adapters/TranscriptionStorageRepositoryAdapter.swift`

- L1: // TranscriptionStorageRepositoryAdapter - Adapter para TranscriptionStorageRepository usando FileSystemStorageService
- L16: // Converter TranscriptionEntity para Transcription (antiga) para compatibilidade
- L129: // O StorageService atual não tem método de delete individual.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreData/Services/StorageService.swift`

- L140: // Setup default directories in Application Support
- L179: // AudioRecorder now supports both M4A and WAV
- L691: // 3. Validate within app container (Application Support)

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/Entities/MeetingEntity.swift`

- L1: // MeetingEntity - Domain Entity pura sem dependências de UI/frameworks
- L6: /// Representa um aplicativo de reunião que pode ser detectado.
- L15: /// Bundle identifiers para detectar este app.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/Entities/TranscriptionEntity.swift`

- L1: // TranscriptionEntity - Domain Entity pura sem dependências de UI/frameworks
- L5: /// Representa uma transcrição completada.
- L10: /// Segmentos da transcrição com identificação de speaker.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/Interfaces/DomainProtocols.swift`

- L1: // Domain Protocols - Interfaces para infraestrutura seguindo Clean Architecture
- L11: // Protocolo para operações de gravação de áudio
- L16: /// Inicia gravação para URL especificada

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/UseCases/ImportAudioUseCase.swift`

- L1: // ImportAudioUseCase - Caso de uso para importar arquivo de áudio
- L5: /// Caso de uso para importar arquivo de áudio externo
- L10: /// Inicializa o caso de uso com dependências

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/UseCases/StartRecordingUseCase.swift`

- L1: // StartRecordingUseCase - Caso de uso para iniciar gravação
- L5: /// Caso de uso para iniciar gravação de reunião
- L11: /// Inicializa o caso de uso com dependências

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/UseCases/StopRecordingUseCase.swift`

- L1: // StopRecordingUseCase - Caso de uso para parar gravação
- L5: /// Caso de uso para parar gravação de reunião
- L10: /// Inicializa o caso de uso com dependências

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Domain/UseCases/TranscribeAudioUseCase.swift`

- L1: // TranscribeAudioUseCase - Caso de uso para transcrever áudio
- L5: /// Caso de uso para transcrever arquivo de áudio
- L11: /// Inicializa o caso de uso com dependências

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/AIPromptTemplates.swift`

- L67: /// - Parameter transcription: The transcription text to process.
- L80: /// - Parameters:
- L99: /// - Parameter userInstructions: Custom instructions to embed.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreDomain/Models/Transcription.swift`

- L37: /// Full initializer with post-processing support.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Infrastructure/CrashReporter.swift`

- L5: /// Manages crash reporting and logging of uncaught exceptions to disk
- L12: // Setup logs directory: ~/Library/Logs/MeetingAssistant/CrashReports
- L14: // Safe unwrap with fallback to temporary directory if library is unavailable (unlikely)

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Infrastructure/PerformanceMonitor.swift`

- L6: /// Monitors application performance and reports metrics
- L56: /// Report a specific metric event immediately

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Models/AppSettings.swift`

- L9: /// Supported AI providers for post-processing transcriptions.
- L55: /// Supported app languages for UI localization.
- L714: // MARK: - Meeting Prompts & Export

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Services/KeychainManager.swift`

- L84: /// - Parameters:
- L116: /// - Parameter key: The key to retrieve the value for.
- L149: /// - Parameter key: The key to delete.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreInfrastructure/Services/MeetingDetector.swift`

- L7: /// Service for detecting active meetings from supported apps.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/Coordinators/AppCoordinator.swift`

- L3: /// Coordinator principal da aplicação.
- L4: /// Gerencia navegação entre telas principais e coordena coordinators filhos.
- L48: // Implementar navegação para trás se necessário

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/Coordinators/SettingsCoordinator.swift`

- L3: /// Coordinator responsável pela navegação dentro das configurações.
- L4: /// Gerencia as abas de configurações e navegação entre elas.
- L16: /// Estado da navegação

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/FloatingRecordingIndicatorController.swift`

- L40: /// - Parameters:
- L56: /// - Parameter mode: Whether to present recording or processing visuals.
- L57: /// - Parameter type: The type of meeting being recorded.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Presentation/PresentationProtocols.swift`

- L5: /// Protocolo base para objetos que podem apresentar views
- L14: /// Protocolo para objetos que coordenam navegação
- L26: /// Navega para uma rota específica

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Services/RecordingManager.swift`

- L142: /// Sincroniza o estado local com o estado do actor (para inicialização).
- L222: /// - Parameters:
- L408: // Cleanup temporary files

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/MeetingSettingsViewModel.swift`

- L96: // MARK: - Export Configuration

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/RecordingViewModel.swift`

- L97: // User said: "se eu clicar no botão em si, ele inicia a gravação de tudo... mas se eu clicar no canto direito, posso escolher..."
- L99: // Let's support passing source.
- L125: /// Import and transcribe an external audio file.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/ViewModels/TranscriptionSettingsViewModel.swift`

- L69: // Dictation = Unknown app source (menu bar dictation) AND not imported file.

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/MeetingSettingsTab.swift`

- L20: // Summary Export Section

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/Settings/Tabs/TranscriptionsSettingsTab.swift`

- L13: // Initialize importViewModel with a closure to refresh the list

### `Packages/MeetingAssistantCore/Sources/MeetingAssistantCoreUI/Views/TranscribeFileButton.swift`

- L3: /// Button component that opens a file picker for importing audio files to transcribe.

