import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public struct MAShortcutControlsRow: View {
    private let title: String
    private let activationMode: Binding<ShortcutActivationMode>?
    private let selectedPresetKey: Binding<PresetShortcutKey>
    private let activationPickerWidth: CGFloat
    private let presetPickerWidth: CGFloat

    public init(
        title: String,
        selectedPresetKey: Binding<PresetShortcutKey>,
        presetPickerWidth: CGFloat = MeetingAssistantDesignSystem.Layout.smallPickerWidth
    ) {
        self.title = title
        self.activationMode = nil
        self.selectedPresetKey = selectedPresetKey
        self.activationPickerWidth = MeetingAssistantDesignSystem.Layout.narrowPickerWidth
        self.presetPickerWidth = presetPickerWidth
    }

    public init(
        title: String,
        activationMode: Binding<ShortcutActivationMode>,
        selectedPresetKey: Binding<PresetShortcutKey>,
        activationPickerWidth: CGFloat = MeetingAssistantDesignSystem.Layout.narrowPickerWidth,
        presetPickerWidth: CGFloat = MeetingAssistantDesignSystem.Layout.smallPickerWidth
    ) {
        self.title = title
        self.activationMode = activationMode
        self.selectedPresetKey = selectedPresetKey
        self.activationPickerWidth = activationPickerWidth
        self.presetPickerWidth = presetPickerWidth
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()

            if let activationMode {
                Picker("", selection: activationMode) {
                    ForEach(ShortcutActivationMode.allCases, id: \.self) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: activationPickerWidth)
            }

            Picker("", selection: selectedPresetKey) {
                ForEach(PresetShortcutKey.allCases, id: \.self) { key in
                    if let icon = key.icon {
                        Label(key.displayName, systemImage: icon).tag(key)
                    } else {
                        Text(key.displayName).tag(key)
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: presetPickerWidth)
        }
    }
}

public struct MAShortcutRecorderRow<RecorderContent: View>: View {
    private let label: String
    private let recorderContent: RecorderContent

    public init(label: String, @ViewBuilder recorderContent: () -> RecorderContent) {
        self.label = label
        self.recorderContent = recorderContent()
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            recorderContent
        }
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
        .background(MeetingAssistantDesignSystem.Colors.secondaryFill)
        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
    }
}

#Preview("Preset Shortcut") {
    PreviewStateContainer(PresetShortcutKey.optionCommand) { key in
        MAShortcutControlsRow(
            title: "Quick Recording Shortcut",
            selectedPresetKey: key
        )
        .padding()
        .frame(width: 520)
    }
}

#Preview("Activation + Preset") {
    PreviewStateContainer(ShortcutActivationMode.holdOrToggle) { mode in
        PreviewStateContainer(PresetShortcutKey.rightCommand) { key in
            MAShortcutControlsRow(
                title: "Meeting Assistant Shortcut",
                activationMode: mode,
                selectedPresetKey: key
            )
            .padding()
            .frame(width: 520)
        }
    }
}
