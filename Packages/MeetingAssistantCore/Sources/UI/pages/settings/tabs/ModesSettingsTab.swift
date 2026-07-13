import SwiftUI

public enum ModesSettingsRoute: Hashable, Sendable {
    case userPrompts
    case postProcessing
}

public struct ModesSettingsTab: View {
    @Binding private var navigationState: SettingsSubpageNavigationState<ModesSettingsRoute>

    public init(
        navigationState: Binding<SettingsSubpageNavigationState<ModesSettingsRoute>> = .constant(SettingsSubpageNavigationState()),
    ) {
        _navigationState = navigationState
    }

    public var body: some View {
        switch navigationState.currentRoute {
        case nil:
            rootPage
        case .userPrompts:
            UserPromptsSettingsTab()
        case .postProcessing:
            EnhancementsSettingsTab(content: .postProcessing)
        }
    }

    private var rootPage: some View {
        SettingsScrollableContent {
            StylesSettingsTab(embedded: true)

            SettingsListGroup("settings.modes.prompts.title".localized, icon: "text.bubble") {
                SettingsListDrillDownButtonRow(
                    title: "settings.dictation.user_prompts.title".localized,
                    subtitle: "settings.dictation.user_prompts.description".localized,
                    accessibilityHint: "settings.dictation.user_prompts.accessibility_hint".localized,
                ) {
                    navigationState.open(.userPrompts)
                }

                SettingsListDrillDownButtonRow(
                    title: "settings.post_processing.title".localized,
                    subtitle: "settings.post_processing.description".localized,
                    accessibilityHint: "settings.post_processing.system_guidelines.accessibility_hint".localized,
                ) {
                    navigationState.open(.postProcessing)
                }
            }
        }
    }
}

#Preview {
    ModesSettingsTab()
}
