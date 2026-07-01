import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Audio Settings Tab

enum AudioInputMode: CaseIterable, Identifiable, Hashable {
    case systemDefault
    case customDevice

    var id: Self {
        self
    }

    var titleKey: String {
        switch self {
        case .systemDefault:
            "settings.general.audio_input_mode.system_default"
        case .customDevice:
            "settings.general.audio_input_mode.custom_device"
        }
    }

    var descriptionKey: String {
        switch self {
        case .systemDefault:
            "settings.general.audio_input_mode.system_default_desc"
        case .customDevice:
            "settings.general.audio_input_mode.custom_device_desc"
        }
    }
}

struct AudioDeviceOption: Identifiable {
    let id: String
    let device: AudioInputDevice?

    static let fallback = AudioDeviceOption(id: "__system_default_fallback__", device: nil)
}

/// Tab for shared audio hardware settings like devices, formats, and system muting.
public struct AudioSettingsTab: View {
    @StateObject var viewModel = GeneralSettingsViewModel()
    @State private var previewingSound: SoundFeedbackSound?
    @State private var previewResetTask: Task<Void, Never>?
    @State var selectedCustomPowerSource = PowerSourceStateProvider().currentPowerSourceState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let showsHeader: Bool

    public init(showsHeader: Bool = true) {
        self.showsHeader = showsHeader
    }

    public var body: some View {
        SettingsScrollableContent {
            if showsHeader {
                SettingsSectionHeader(
                    title: "settings.section.audio".localized,
                    description: "settings.general.audio_devices_desc".localized
                )
            }

            // Audio Devices
            DSGroup("settings.general.audio_devices".localized, icon: "mic.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    audioInputModePicker

                    if audioInputMode == .systemDefault {
                        systemDefaultDeviceSection
                            .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
                    } else {
                        customDeviceSection
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

            recordingIndicatorSection
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

    private var audioDuckingSliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.audioDuckingLevelPercent) },
            set: { viewModel.audioDuckingLevelPercent = Int($0.rounded()) }
        )
    }

    private var recordingIndicatorSection: some View {
        DSGroup("settings.general.recording_indicator".localized, icon: "record.circle") {
            VStack(alignment: .leading, spacing: 16) {
                DSToggleRow(
                    "settings.general.recording_indicator.enabled".localized,
                    description: "settings.general.recording_indicator.enabled_desc".localized,
                    isOn: $viewModel.recordingIndicatorEnabled.animated()
                )

                if viewModel.recordingIndicatorEnabled {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()

                        HStack {
                            Text("settings.general.recording_indicator.style".localized)
                                .font(.body)

                            Spacer()

                            Picker("", selection: $viewModel.recordingIndicatorStyle) {
                                ForEach(RecordingIndicatorStyle.allCases, id: \.self) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        HStack {
                            Text("settings.general.recording_indicator.position".localized)
                                .font(.body)

                            Spacer()

                            Picker("", selection: $viewModel.recordingIndicatorPosition) {
                                ForEach(RecordingIndicatorPosition.allCases, id: \.self) { pos in
                                    Text(pos.displayName).tag(pos)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        HStack(spacing: 12) {
                            SettingsTitleWithPopover(
                                title: "settings.general.recording_indicator.animation_speed".localized,
                                helperMessage: "settings.general.recording_indicator.animation_speed_desc".localized
                            )

                            Spacer()

                            Picker("", selection: $viewModel.recordingIndicatorAnimationSpeed) {
                                ForEach(RecordingIndicatorAnimationSpeed.allCases, id: \.self) { speed in
                                    Text(speed.displayName).tag(speed)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                    }
                    .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
                }
            }
        }
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
