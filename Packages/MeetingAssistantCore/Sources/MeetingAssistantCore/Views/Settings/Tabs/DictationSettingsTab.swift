import KeyboardShortcuts
import SwiftUI

// MARK: - Dictation Settings Tab

/// Tab for dictation-specific settings like auto-copy/paste and shortcuts.
public struct DictationSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                // Workflow
                SettingsGroup("settings.dictation.workflow".localized, icon: "cpu") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
                            "settings.general.auto_copy_transcription".localized,
                            description: "settings.general.auto_copy_transcription_desc".localized,
                            isOn: $viewModel.autoCopyTranscriptionToClipboard
                        )

                        Divider()

                        SettingsToggle(
                            "settings.general.auto_paste_transcription".localized,
                            isOn: $viewModel.autoPasteTranscriptionToActiveApp
                        )
                    }
                }

                // Keyboard Shortcut
                SettingsGroup("settings.shortcuts.dictation".localized, icon: "keyboard") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("settings.shortcuts.dictation_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.shortcuts.dictation".localized)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            Picker("", selection: $shortcutsViewModel.dictationSelectedPresetKey) {
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

                        if shortcutsViewModel.dictationSelectedPresetKey == .custom {
                            Divider()

                            HStack {
                                Text("settings.shortcuts.custom_shortcut".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                KeyboardShortcuts.Recorder(for: .dictationToggle)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Sound Feedback
                SettingsGroup("settings.general.sound_feedback".localized, icon: "speaker.wave.2.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
                            "settings.general.sound_feedback.enabled".localized,
                            description: "settings.general.sound_feedback.enabled_desc".localized,
                            isOn: $viewModel.soundFeedbackEnabled
                        )

                        if viewModel.soundFeedbackEnabled {
                            Divider()

                            soundPickerRow(
                                title: "settings.general.sound_feedback.start_sound".localized,
                                selection: $viewModel.recordingStartSound
                            )

                            Divider()

                            soundPickerRow(
                                title: "settings.general.sound_feedback.stop_sound".localized,
                                selection: $viewModel.recordingStopSound
                            )
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func soundPickerRow(title: String, selection: Binding<SoundFeedbackSound>) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: selection) {
                ForEach(SoundFeedbackSound.allCases, id: \.self) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)

            Button {
                SoundFeedbackService.shared.preview(selection.wrappedValue)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(selection.wrappedValue == .none)
            .accessibilityLabel("settings.general.sound_feedback.preview".localized)
        }
    }
}

#Preview {
    DictationSettingsTab()
}
