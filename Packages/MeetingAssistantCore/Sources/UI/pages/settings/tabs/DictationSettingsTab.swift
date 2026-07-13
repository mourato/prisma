import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public enum DictationSettingsRoute: Hashable, Sendable {
    case modes
    case postProcessing
    case userPrompts
}

// MARK: - Dictation Settings Tab

/// Tab for dictation-specific settings like auto-copy/paste and shortcuts.
public struct DictationSettingsTab: View {
    @Binding private var navigationState: SettingsSubpageNavigationState<DictationSettingsRoute>
    @State private var viewModel: GeneralSettingsViewModel
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()
    @StateObject private var serviceViewModel: ServiceSettingsViewModel

    public init(
        settings: AppSettingsStore = .shared,
        navigationState: Binding<SettingsSubpageNavigationState<DictationSettingsRoute>> = .constant(SettingsSubpageNavigationState()),
    ) {
        _navigationState = navigationState
        _viewModel = State(wrappedValue: GeneralSettingsViewModel(settingsStore: settings))
        _serviceViewModel = StateObject(wrappedValue: ServiceSettingsViewModel(settings: settings))
    }

    public var body: some View {
        switch navigationState.currentRoute {
        case nil:
            rootPage
        case .some:
            rootPage
        }
    }

    private var rootPage: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.dictation".localized,
                description: "settings.dictation.description".localized,
            )

            ShortcutSettingsSection(
                groupTitle: "settings.shortcuts.dictation".localized,
                descriptionText: "settings.shortcuts.dictation_desc".localized,
                settingsContent: {
                    VStack(alignment: .leading, spacing: 12) {
                        if let healthPresentation = shortcutsViewModel.shortcutCaptureHealthPresentation {
                            ShortcutCaptureHealthStatusView(presentation: healthPresentation) {
                                shortcutsViewModel.openShortcutCaptureHealthAction()
                            }
                        }

                        DSModifierShortcutEditor(
                            shortcut: $shortcutsViewModel.dictationShortcutDefinition,
                            conflictMessage: shortcutsViewModel.dictationModifierConflictMessage,
                        )
                    }
                },
            )

            SettingsListGroup("settings.dictation.text_handling".localized, icon: "cpu") {
                DSToggleRow(
                    "settings.general.auto_copy_transcription".localized,
                    description: "settings.general.auto_copy_transcription_desc".localized,
                    isOn: $viewModel.autoCopyTranscriptionToClipboard,
                )

                DSToggleRow(
                    "settings.general.auto_paste_transcription".localized,
                    isOn: $viewModel.autoPasteTranscriptionToActiveApp,
                )

                DSToggleRow(
                    "settings.dictation.smart_spacing".localized,
                    description: "settings.dictation.smart_spacing_desc".localized,
                    isOn: $viewModel.smartSpacingAndCapitalizationEnabled,
                )

                DSToggleRow(
                    "settings.dictation.smart_paragraphs".localized,
                    description: "settings.dictation.smart_paragraphs_desc".localized,
                    isOn: $viewModel.smartParagraphsEnabled,
                )
            }

            ServiceTranscriptionProviderSection(viewModel: serviceViewModel)
        }
    }
}

#Preview {
    DictationSettingsTab()
}
