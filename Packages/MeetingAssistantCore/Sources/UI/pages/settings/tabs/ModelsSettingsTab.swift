import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Models Settings Tab

/// Tab for configuring transcription provider and local model settings.
public struct ModelsSettingsTab: View {
    @StateObject private var viewModel: ServiceSettingsViewModel
    @StateObject private var aiSettingsViewModel: AISettingsViewModel
    @StateObject private var postProcessingViewModel: PostProcessingSettingsViewModel

    @MainActor
    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: ServiceSettingsViewModel(settings: settings))
        _aiSettingsViewModel = StateObject(wrappedValue: AISettingsViewModel(settings: settings))
        _postProcessingViewModel = StateObject(wrappedValue: PostProcessingSettingsViewModel(settings: settings))
    }

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.models".localized,
                description: "settings.models.description".localized
            )

            EnhancementsProviderModelsPage(
                viewModel: aiSettingsViewModel,
                postProcessingViewModel: postProcessingViewModel
            )

            ServiceSettingsContent(
                viewModel: viewModel,
                includeTranscriptionProviderSection: false,
                includeMeetingTranscriptionSection: false
            )
        }
    }
}

#Preview {
    ModelsSettingsTab()
}
