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

                    DSToggleRow(
                        "settings.general.mute_output_during_recording".localized,
                        description: "settings.general.mute_output_desc".localized,
                        isOn: $viewModel.muteOutputDuringRecording
                    )

                    Divider()

                    DSToggleRow(
                        "settings.general.auto_increase_microphone_volume".localized,
                        tooltip: "settings.general.auto_increase_microphone_volume_tooltip".localized,
                        isOn: $viewModel.autoIncreaseMicrophoneVolume
                    )
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
