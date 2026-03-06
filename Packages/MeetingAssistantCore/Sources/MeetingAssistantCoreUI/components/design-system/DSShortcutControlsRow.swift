import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct DSShortcutControlsRow: View {
    private let title: String
    private let activationMode: Binding<ShortcutActivationMode>?
    private let selectedPresetKey: Binding<PresetShortcutKey>
    private let activationPickerWidth: CGFloat
    private let presetPickerWidth: CGFloat

    public init(
        title: String,
        selectedPresetKey: Binding<PresetShortcutKey>,
        presetPickerWidth: CGFloat = AppDesignSystem.Layout.smallPickerWidth
    ) {
        self.title = title
        activationMode = nil
        self.selectedPresetKey = selectedPresetKey
        activationPickerWidth = AppDesignSystem.Layout.narrowPickerWidth
        self.presetPickerWidth = presetPickerWidth
    }

    public init(
        title: String,
        activationMode: Binding<ShortcutActivationMode>,
        selectedPresetKey: Binding<PresetShortcutKey>,
        activationPickerWidth: CGFloat = AppDesignSystem.Layout.narrowPickerWidth,
        presetPickerWidth: CGFloat = AppDesignSystem.Layout.smallPickerWidth
    ) {
        self.title = title
        self.activationMode = activationMode
        self.selectedPresetKey = selectedPresetKey
        self.activationPickerWidth = activationPickerWidth
        self.presetPickerWidth = presetPickerWidth
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing4) {
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

public struct DSShortcutRecorderRow<RecorderContent: View>: View {
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
        .padding(.vertical, AppDesignSystem.Layout.spacing8)
        .padding(.horizontal, AppDesignSystem.Layout.spacing12)
        .background(AppDesignSystem.Colors.secondaryFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
    }
}

#Preview("Preset Shortcut") {
    PreviewStateContainer(PresetShortcutKey.optionCommand) { key in
        DSShortcutControlsRow(
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
            DSShortcutControlsRow(
                title: "Prisma Shortcut",
                activationMode: mode,
                selectedPresetKey: key
            )
            .padding()
            .frame(width: 520)
        }
    }
}
