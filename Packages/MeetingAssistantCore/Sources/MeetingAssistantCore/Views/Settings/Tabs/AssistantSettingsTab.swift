import KeyboardShortcuts
import SwiftUI

public struct AssistantSettingsTab: View {
    @StateObject private var viewModel = AssistantShortcutSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
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
        Text(NSLocalizedString("settings.assistant.header_desc", bundle: .safeModule, comment: ""))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assistantControlsSection: some View {
        SettingsGroup(
            NSLocalizedString("settings.assistant.controls", bundle: .safeModule, comment: ""),
            icon: "sparkles"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.assistant.toggle_command", bundle: .safeModule, comment: ""))
                            .font(.body)
                            .fontWeight(.medium)
                        Text(NSLocalizedString("settings.assistant.toggle_command_desc", bundle: .safeModule, comment: ""))
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
                    .frame(width: 140)

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
                    .frame(width: 150)
                }

                if viewModel.isRecordingCustomShortcut {
                    HStack {
                        Text(NSLocalizedString("settings.assistant.custom_shortcut", bundle: .safeModule, comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        KeyboardShortcuts.Recorder(for: .assistantCommand)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Divider()

                Text(NSLocalizedString("settings.assistant.activation_mode_desc", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var visualFeedbackSection: some View {
        SettingsGroup(
            NSLocalizedString("settings.assistant.visual_feedback", bundle: .safeModule, comment: ""),
            icon: "rectangle.inset.filled"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Border Color Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.assistant.border_color", bundle: .safeModule, comment: ""))
                        .font(.body)
                        .fontWeight(.medium)

                    HStack(spacing: 12) {
                        SettingsThemePicker(selection: $viewModel.borderColor)
                    }
                }

                Divider()

                // Border Style Picker
                HStack {
                    Text(NSLocalizedString("settings.assistant.border_style", bundle: .safeModule, comment: ""))
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
                    .frame(width: 200)
                }
            }
        }
    }


    private var optionsSection: some View {
        SettingsCard {
            SettingsToggle(
                NSLocalizedString("settings.assistant.use_escape", bundle: .safeModule, comment: ""),
                isOn: $viewModel.useEscapeToCancelRecording
            )
        }
    }

    private var testKeysSection: some View {
        SettingsGroup(
            NSLocalizedString("settings.assistant.try_keys", bundle: .safeModule, comment: ""),
            icon: "keyboard"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .foregroundStyle(.blue)
                    Text(NSLocalizedString("settings.assistant.try_keys_hint", bundle: .safeModule, comment: ""))
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
        SettingsCard {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)

                Button(action: {
                    viewModel.resetShortcuts()
                }) {
                    Text(NSLocalizedString("settings.assistant.reset", bundle: .safeModule, comment: ""))
                }
                .buttonStyle(.link)

                Spacer()
            }
        }
    }
}

#Preview {
    AssistantSettingsTab()
}
