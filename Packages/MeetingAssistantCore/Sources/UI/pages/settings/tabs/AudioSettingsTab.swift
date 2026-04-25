import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Audio Settings Tab

/// Tab for shared audio hardware settings like devices, formats, and system muting.
public struct AudioSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @State private var previewingSound: SoundFeedbackSound?
    @State private var previewResetTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.audio".localized,
                description: "settings.general.audio_devices_desc".localized
            )

            // Audio Devices
            DSGroup("settings.general.audio_devices".localized, icon: "mic.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    DSToggleRow(
                        "settings.general.use_system_default_input".localized,
                        description: "settings.general.use_system_default_input_desc".localized,
                        isOn: $viewModel.useSystemDefaultInput.animated()
                    )

                    if !viewModel.useSystemDefaultInput {
                        VStack(alignment: .leading, spacing: 16) {
                            microphonePickerRow(
                                title: "settings.general.microphone_when_charging".localized,
                                selection: $viewModel.microphoneWhenChargingUID,
                                helperMessage: "settings.general.power_based_microphone_desc".localized
                            )

                            microphonePickerRow(
                                title: "settings.general.microphone_on_battery".localized,
                                selection: $viewModel.microphoneOnBatteryUID
                            )
                        }
                        .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
                    }

                    Divider()

                    HStack {
                        SettingsTitleWithPopover(
                            title: "settings.general.recording_media_handling".localized,
                            helperMessage: "settings.general.recording_media_handling_desc".localized
                        )

                        Spacer()

                        Picker("", selection: $viewModel.recordingMediaHandlingMode) {
                            ForEach(AppSettingsStore.RecordingMediaHandlingMode.allCases, id: \.self) { mode in
                                Text(mode.displayNameKey.localized)
                                    .tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: AppDesignSystem.Layout.smallPickerWidth)
                    }

                    if viewModel.usesDuckingControls {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "speaker.slash")
                                    .foregroundStyle(.secondary)

                                Slider(
                                    value: audioDuckingSliderBinding,
                                    in: 0...100,
                                    step: 1
                                )
                                .controlSize(.small)

                                Image(systemName: "speaker.wave.2")
                                    .foregroundStyle(.secondary)
                            }

                            Text(
                                String(
                                    format: "settings.general.audio_ducking_percent".localized,
                                    viewModel.audioDuckingLevelPercent
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text("settings.general.audio_ducking_note".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if viewModel.recordingMediaHandlingMode == .pauseMedia {
                                Text("settings.general.recording_media_handling_pause_note".localized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
                    }

                    Divider()

                    DSToggleRow(
                        "settings.general.auto_increase_microphone_volume".localized,
                        tooltip: "settings.general.auto_increase_microphone_volume_tooltip".localized,
                        isOn: $viewModel.autoIncreaseMicrophoneVolume
                    )
                }
            }

            DSGroup("settings.general.audio_processing".localized, icon: "waveform.badge.minus") {
                VStack(alignment: .leading, spacing: 12) {
                    DSToggleRow(
                        "settings.general.remove_silence_before_processing".localized,
                        description: "settings.general.remove_silence_before_processing_desc".localized,
                        isOn: $viewModel.removeSilenceBeforeProcessing
                    )

                    Text("settings.general.remove_silence_before_processing_note".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Sound Feedback
            DSGroup("settings.general.sound_feedback".localized, icon: "speaker.wave.2.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    DSToggleRow(
                        "settings.general.sound_feedback.enabled".localized,
                        description: "settings.general.sound_feedback.enabled_desc".localized,
                        isOn: $viewModel.soundFeedbackEnabled.animated()
                    )

                    if viewModel.soundFeedbackEnabled {
                        VStack(alignment: .leading, spacing: 16) {
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
                        .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
                    }
                }
            }
        }
    }

    private func soundPickerRow(title: String, selection: Binding<SoundFeedbackSound>) -> some View {
        HStack {
            SettingsTitleWithPopover(title: title)

            Spacer()

            Picker("", selection: selection) {
                ForEach(SoundFeedbackSound.allCases, id: \.self) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: AppDesignSystem.Layout.smallPickerWidth)

            Button {
                previewSound(selection.wrappedValue)
            } label: {
                Image(systemName: previewingSound == selection.wrappedValue ? "speaker.wave.2.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .settingsPulseSymbolEffect(
                        isActive: previewingSound == selection.wrappedValue,
                        reduceMotion: reduceMotion
                    )
            }
            .buttonStyle(.borderless)
            .disabled(selection.wrappedValue == .none)
            .accessibilityLabel("settings.general.sound_feedback.preview".localized)
            .accessibilityHint("settings.general.sound_feedback.enabled_desc".localized)
        }
    }

    private func microphonePickerRow(
        title: String,
        selection: Binding<String?>,
        helperMessage: String? = nil
    ) -> some View {
        HStack {
            SettingsTitleWithPopover(
                title: title,
                helperMessage: helperMessage
            )

            Spacer()

            Picker("", selection: selection) {
                Text("settings.general.device_not_selected".localized)
                    .tag(String?.none)

                ForEach(viewModel.availableDevices) { device in
                    Text(microphoneOptionTitle(for: device))
                        .tag(Optional(device.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: AppDesignSystem.Layout.smallPickerWidth)
        }
    }

    private func microphoneOptionTitle(for device: AudioInputDevice) -> String {
        if !device.isAvailable {
            return "\(device.name) (\("settings.general.device_unavailable".localized))"
        }

        if device.isDefault {
            return "\(device.name) (\("settings.general.device_default".localized))"
        }

        return device.name
    }

    private var audioDuckingSliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.audioDuckingLevelPercent) },
            set: { viewModel.audioDuckingLevelPercent = Int($0.rounded()) }
        )
    }

    private func previewSound(_ sound: SoundFeedbackSound) {
        guard sound != .none else { return }
        previewResetTask?.cancel()
        previewingSound = sound
        SoundFeedbackService.shared.preview(sound)
        previewResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            previewingSound = nil
        }
    }
}

#Preview {
    AudioSettingsTab()
}
