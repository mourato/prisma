import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct MAShortcutSettingsSection<RecorderContent: View>: View {
    private let groupTitle: String
    private let groupIcon: String
    private let descriptionText: String
    private let shortcutTitle: String
    private let customShortcutLabel: String
    private let activationModeDescription: String
    private let activationMode: Binding<ShortcutActivationMode>
    private let selectedPresetKey: Binding<PresetShortcutKey>
    private let recorderContent: () -> RecorderContent

    public init(
        groupTitle: String,
        groupIcon: String = "keyboard",
        descriptionText: String,
        shortcutTitle: String,
        customShortcutLabel: String,
        activationModeDescription: String,
        activationMode: Binding<ShortcutActivationMode>,
        selectedPresetKey: Binding<PresetShortcutKey>,
        @ViewBuilder recorderContent: @escaping () -> RecorderContent
    ) {
        self.groupTitle = groupTitle
        self.groupIcon = groupIcon
        self.descriptionText = descriptionText
        self.shortcutTitle = shortcutTitle
        self.customShortcutLabel = customShortcutLabel
        self.activationModeDescription = activationModeDescription
        self.activationMode = activationMode
        self.selectedPresetKey = selectedPresetKey
        self.recorderContent = recorderContent
    }

    public var body: some View {
        MAGroup(groupTitle, icon: groupIcon) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                Text(descriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MAShortcutControlsRow(
                    title: shortcutTitle,
                    activationMode: activationMode,
                    selectedPresetKey: selectedPresetKey
                )

                if selectedPresetKey.wrappedValue == .custom {
                    Divider()

                    MAShortcutRecorderRow(label: customShortcutLabel) {
                        recorderContent()
                    }
                }

                Divider()

                Text(activationModeDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    PreviewStateContainer(ShortcutActivationMode.holdOrToggle) { mode in
        PreviewStateContainer(PresetShortcutKey.optionCommand) { key in
            MAShortcutSettingsSection(
                groupTitle: "Shortcuts",
                descriptionText: "Configure the shortcut behavior.",
                shortcutTitle: "Dictation shortcut",
                customShortcutLabel: "Custom shortcut",
                activationModeDescription: "Choose how the shortcut should trigger.",
                activationMode: mode,
                selectedPresetKey: key
            ) {
                Text("Recorder")
                    .font(.caption)
            }
            .padding()
            .frame(width: 620)
        }
    }
}
