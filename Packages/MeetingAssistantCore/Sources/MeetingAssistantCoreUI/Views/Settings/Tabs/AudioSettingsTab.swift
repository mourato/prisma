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
    @State private var draggingDevice: AudioInputDevice?
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
                VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing12) {
                    DSToggleRow(
                        "settings.general.use_system_default_input".localized,
                        description: "settings.general.use_system_default_input_desc".localized,
                        isOn: $viewModel.useSystemDefaultInput.animated()
                    )

                    if !viewModel.useSystemDefaultInput {
                        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing12) {
                            Text("settings.general.audio_devices_desc".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(spacing: AppDesignSystem.Layout.spacing8) {
                                ForEach(viewModel.availableDevices) { device in
                                    HStack(spacing: AppDesignSystem.Layout.spacing12) {
                                        Image(systemName: device.isAvailable ? "mic" : "mic.slash")
                                            .foregroundStyle(device.isAvailable ? .primary : .secondary)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(device.name)
                                                .font(.body)
                                                .foregroundStyle(device.isAvailable ? .primary : .secondary)
                                            if device.isDefault {
                                                Text("settings.general.device_default".localized)
                                                    .font(.caption2)
                                                    .foregroundStyle(AppDesignSystem.Colors.accent)
                                            }
                                        }

                                        Spacer()

                                        if !device.isAvailable {
                                            Text("settings.general.device_unavailable".localized)
                                                .font(.caption2)
                                                .foregroundStyle(AppDesignSystem.Colors.error)
                                        }

                                        Image(systemName: "line.3.horizontal")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(AppDesignSystem.Layout.spacing8)
                                    .background(AppDesignSystem.Colors.subtleFill2)
                                    .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
                                    .onDrag {
                                        draggingDevice = device
                                        return NSItemProvider(object: device.id as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: DeviceDropDelegate(
                                        item: device,
                                        listData: $viewModel.availableDevices,
                                        current: $draggingDevice,
                                        onMove: viewModel.moveDevice
                                    ))
                                }
                            }
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
                VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing16) {
                    DSToggleRow(
                        "settings.general.sound_feedback.enabled".localized,
                        description: "settings.general.sound_feedback.enabled_desc".localized,
                        isOn: $viewModel.soundFeedbackEnabled.animated()
                    )

                    if viewModel.soundFeedbackEnabled {
                        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing16) {
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

// MARK: - Drop Delegate

struct DeviceDropDelegate: DropDelegate {
    let item: AudioInputDevice
    @Binding var listData: [AudioInputDevice]
    @Binding var current: AudioInputDevice?
    var onMove: (IndexSet, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        current = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let current,
              current != item,
              let from = listData.firstIndex(of: current),
              let to = listData.firstIndex(of: item) else { return }

        if listData[to] != current {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onMove(IndexSet(integer: from), to > from ? to + 1 : to)
            }
        }
    }
}

#Preview {
    AudioSettingsTab()
}
