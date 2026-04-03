import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct ShortcutSettingsSection<SettingsContent: View>: View {
    private let groupTitle: String
    private let groupIcon: String
    private let descriptionText: String
    private let settingsContent: () -> SettingsContent

    public init(
        groupTitle: String,
        groupIcon: String = "keyboard",
        descriptionText: String,
        @ViewBuilder settingsContent: @escaping () -> SettingsContent
    ) {
        self.groupTitle = groupTitle
        self.groupIcon = groupIcon
        self.descriptionText = descriptionText
        self.settingsContent = settingsContent
    }

    public var body: some View {
        DSGroup(
            groupTitle,
            icon: groupIcon,
            headerAccessory: {
                HStack(spacing: 8) {
                    if !descriptionText.isEmpty {
                        DSInfoPopoverButton(
                            title: groupTitle,
                            message: descriptionText
                        )
                    }

                    DSInfoPopoverButton(
                        title: "settings.shortcuts.external_remap.title".localized,
                        message: "settings.shortcuts.external_remap.message".localized
                    )
                }
            }
        ) {
            settingsContent()
        }
    }
}

#Preview {
    ShortcutSettingsSection(
        groupTitle: "Shortcuts",
        descriptionText: "Configure the shortcut behavior."
    ) {
        Text("In-house shortcut editor")
            .font(.caption)
    }
    .padding()
    .frame(width: 620)
}
