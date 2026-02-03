import KeyboardShortcuts
import SwiftUI

/// Settings section for configuring Recording keyboard controls.
public struct RecordingKeyboardControlsSection: View {
    @ObservedObject private var viewModel: ShortcutSettingsViewModel

    public init(viewModel: ShortcutSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
            headerSection
            recordingControlsSection
            tipsSection
            optionsSection
            testKeysSection
            resetSection
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        Text(NSLocalizedString("settings.shortcuts.header_desc", bundle: .safeModule, comment: ""))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var recordingControlsSection: some View {
        SettingsGroup(
            NSLocalizedString("settings.shortcuts.recording_controls", bundle: .safeModule, comment: ""),
            icon: "record.circle"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.shortcuts.toggle_recording", bundle: .safeModule, comment: ""))
                            .font(.body)
                            .fontWeight(.medium)
                        Text(NSLocalizedString("settings.shortcuts.toggle_recording_desc", bundle: .safeModule, comment: ""))
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
                        Text(NSLocalizedString("settings.shortcuts.custom_shortcut", bundle: .safeModule, comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        KeyboardShortcuts.Recorder(for: .toggleRecording)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Divider()

                Text(NSLocalizedString("settings.shortcuts.activation_mode_desc", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var tipsSection: some View {
        SettingsGroup(
            NSLocalizedString("settings.shortcuts.tips_title", bundle: .safeModule, comment: ""),
            icon: "lightbulb"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.shortcuts.fn_key_title", bundle: .safeModule, comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(NSLocalizedString("settings.shortcuts.fn_key_desc", bundle: .safeModule, comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var optionsSection: some View {
        SettingsCard {
            SettingsToggle(
                NSLocalizedString("settings.shortcuts.use_escape", bundle: .safeModule, comment: ""),
                isOn: $viewModel.useEscapeToCancelRecording
            )
        }
    }

    @ViewBuilder
    private var testKeysSection: some View {
        SettingsGroup(
            NSLocalizedString("settings.shortcuts.try_keys", bundle: .safeModule, comment: ""),
            icon: "keyboard"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .foregroundStyle(.blue)
                    Text(NSLocalizedString("settings.shortcuts.try_keys_hint", bundle: .safeModule, comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("", text: $viewModel.testKeysInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 80)
                    .disabled(true)
                    .opacity(0.5)
            }
        }
    }

    @ViewBuilder
    private var resetSection: some View {
        SettingsCard {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)

                Button(action: {
                    viewModel.resetShortcuts()
                }) {
                    Text(NSLocalizedString("settings.shortcuts.reset", bundle: .safeModule, comment: ""))
                }
                .buttonStyle(.link)

                Spacer()
            }
        }
    }
}

#Preview {
    RecordingKeyboardControlsSection(viewModel: ShortcutSettingsViewModel())
        .padding()
}
