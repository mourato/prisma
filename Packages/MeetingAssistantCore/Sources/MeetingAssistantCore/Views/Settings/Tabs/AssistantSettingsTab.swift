import KeyboardShortcuts
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
        MAGroup(
            "settings.assistant.controls".localized,
            icon: "sparkles"
        ) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.assistant.toggle_command".localized)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("settings.assistant.toggle_command_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $viewModel.activationMode) {
                        ForEach(ShortcutActivationMode.allCases, id: \.self) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: MeetingAssistantDesignSystem.Layout.narrowPickerWidth)

                    Picker("", selection: $viewModel.selectedPresetKey) {
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
                    .frame(width: MeetingAssistantDesignSystem.Layout.smallPickerWidth)
                }

                if viewModel.isRecordingCustomShortcut {
                    HStack {
                        Text("settings.assistant.custom_shortcut".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        KeyboardShortcuts.Recorder(for: .assistantCommand)
                    }
                    .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
                    .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
                    .background(MeetingAssistantDesignSystem.Colors.secondaryFill)
                    .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
                }

                Divider()

                Text("settings.assistant.activation_mode_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
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
