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
        MAGroup(groupTitle, icon: groupIcon) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                Text(descriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                settingsContent()
            }
        }
    }
}

#Preview {
    MAShortcutSettingsSection(
        groupTitle: "Shortcuts",
        descriptionText: "Configure the shortcut behavior."
    ) {
        Text("In-house shortcut editor")
            .font(.caption)
    }
    .padding()
    .frame(width: 620)
}
