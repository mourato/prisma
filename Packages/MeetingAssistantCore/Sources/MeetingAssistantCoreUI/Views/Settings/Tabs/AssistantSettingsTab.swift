import KeyboardShortcuts
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct AssistantSettingsTab: View {
    @StateObject private var viewModel = AssistantShortcutSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                headerSection
                assistantControlsSection
                visualFeedbackSection
                optionsSection
                testKeysSection
                resetSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerSection: some View {
        Text("settings.assistant.header_desc".localized)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assistantControlsSection: some View {
        MAShortcutSettingsSection(
            groupTitle: "settings.assistant.controls".localized,
            groupIcon: "sparkles",
            descriptionText: "settings.assistant.toggle_command_desc".localized,
            shortcutTitle: "settings.assistant.toggle_command".localized,
            customShortcutLabel: "settings.assistant.custom_shortcut".localized,
            activationModeDescription: "settings.assistant.activation_mode_desc".localized,
            activationMode: $viewModel.activationMode,
            selectedPresetKey: $viewModel.selectedPresetKey
        ) {
            KeyboardShortcuts.Recorder(for: .assistantCommand)
        }
    }

    private var visualFeedbackSection: some View {
        MAGroup(
            "settings.assistant.visual_feedback".localized,
            icon: "rectangle.inset.filled"
        ) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                // Border Color Picker
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Text("settings.assistant.border_color".localized)
                        .font(.body)
                        .fontWeight(.medium)

                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                        MAThemePicker(selection: $viewModel.borderColor)
                    }
                }

                Divider()

                // Border Style Picker
                HStack {
                    Text("settings.assistant.border_style".localized)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    Picker("", selection: $viewModel.borderStyle) {
                        ForEach(AssistantBorderStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
                }
            }
        }
    }

    private var optionsSection: some View {
        MACard {
            MAToggleRow(
                "settings.assistant.use_escape".localized,
                isOn: $viewModel.useEscapeToCancelRecording
            )
        }
    }

    private var testKeysSection: some View {
        MAGroup(
            "settings.assistant.try_keys".localized,
            icon: "keyboard"
        ) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                    Text("settings.assistant.try_keys_hint".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("", text: $viewModel.testKeysInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 80)
            }
        }
    }

    private var resetSection: some View {
        MACard {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)

                Button(
                    action: { viewModel.resetShortcuts() },
                    label: {
                        Text("settings.assistant.reset".localized)
                    }
                )
                .buttonStyle(.link)

                Spacer()
            }
        }
    }
}

#Preview {
    AssistantSettingsTab()
}
