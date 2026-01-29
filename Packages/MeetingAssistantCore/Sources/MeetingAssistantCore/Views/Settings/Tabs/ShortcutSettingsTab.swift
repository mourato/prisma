import KeyboardShortcuts
import SwiftUI

// MARK: - Shortcut Settings Tab

/// Tab for configuring global keyboard shortcuts.
/// Design inspired by Spokenly's Keyboard Controls interface.
public struct ShortcutSettingsTab: View {
    @StateObject private var viewModel = ShortcutSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                headerSection
                recordingControlsSection
                tipsSection
                optionsSection
                testKeysSection
                resetSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        Text(NSLocalizedString("settings.shortcuts.header_desc", bundle: .safeModule, comment: ""))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Recording Controls Section

    @ViewBuilder
    private var recordingControlsSection: some View {
        SettingsGroup(
            NSLocalizedString("settings.shortcuts.recording_controls", bundle: .safeModule, comment: ""),
            icon: "record.circle"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Toggle Recording Shortcut
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

                    // Activation Mode Picker (now enabled)
                    Picker("", selection: $viewModel.activationMode) {
                        ForEach(ShortcutActivationMode.allCases, id: \.self) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)

                    // Preset Key Picker
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

                // Show custom shortcut recorder when "Record shortcut..." is selected
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

                // Description of activation modes
                Text(NSLocalizedString("settings.shortcuts.activation_mode_desc", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Tips Section

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

    // MARK: - Options Section

    @ViewBuilder
    private var optionsSection: some View {
        SettingsCard {
            SettingsToggle(
                NSLocalizedString("settings.shortcuts.use_escape", bundle: .safeModule, comment: ""),
                isOn: $viewModel.useEscapeToCancelRecording
            )
        }
    }

    // MARK: - Test Keys Section

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

                // Text field for testing keys (placeholder - basic functionality)
                TextField("", text: $viewModel.testKeysInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 80)
                    .disabled(true)
                    .opacity(0.5)
            }
        }
    }

    // MARK: - Reset Section

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
    ShortcutSettingsTab()
}
