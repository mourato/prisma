import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct MAShortcutSettingsSection<SettingsContent: View>: View {
    private let groupTitle: String
    private let groupIcon: String
    private let descriptionText: String
    private let activationModeDescription: String
    private let settingsContent: () -> SettingsContent

    public init(
        groupTitle: String,
        groupIcon: String = "keyboard",
        descriptionText: String,
        activationModeDescription: String,
        @ViewBuilder settingsContent: @escaping () -> SettingsContent
    ) {
        self.groupTitle = groupTitle
        self.groupIcon = groupIcon
        self.descriptionText = descriptionText
        self.activationModeDescription = activationModeDescription
        self.settingsContent = settingsContent
    }

    public var body: some View {
        MAGroup(groupTitle, icon: groupIcon) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                Text(descriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                settingsContent()

                Divider()

                Text(activationModeDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    MAShortcutSettingsSection(
        groupTitle: "Shortcuts",
        descriptionText: "Configure the shortcut behavior.",
        activationModeDescription: "Choose how the shortcut should trigger."
    ) {
        Text("In-house shortcut editor")
            .font(.caption)
    }
    .padding()
    .frame(width: 620)
}
