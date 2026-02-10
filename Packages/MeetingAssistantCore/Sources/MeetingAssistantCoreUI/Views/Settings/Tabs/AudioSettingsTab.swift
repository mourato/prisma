import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Audio Settings Tab

/// Tab for shared audio hardware settings like devices, formats, and system muting.
public struct AudioSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @State private var draggingDevice: AudioInputDevice?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                // Audio Devices
                MAGroup("settings.general.audio_devices".localized, icon: "mic.fill") {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                        MAToggleRow(
                            "settings.general.use_system_default_input".localized,
                            description: "settings.general.use_system_default_input_desc".localized,
                            isOn: $viewModel.useSystemDefaultInput
                        )

                        if !viewModel.useSystemDefaultInput {
                            Text("settings.general.audio_devices_desc".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                                ForEach(viewModel.availableDevices) { device in
                                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
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
                                                    .foregroundStyle(.blue)
                                            }
                                        }

                                        Spacer()

                                        if !device.isAvailable {
                                            Text("settings.general.device_unavailable".localized)
                                                .font(.caption2)
                                                .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
                                        }

                                        Image(systemName: "line.3.horizontal")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(MeetingAssistantDesignSystem.Layout.spacing8)
                                    .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
                                    .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
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

                        Divider()

                        MAToggleRow(
                            "settings.general.mute_output_during_recording".localized,
                            description: "settings.general.mute_output_desc".localized,
                            isOn: $viewModel.muteOutputDuringRecording
                        )

                        MAToggleRow(
                            "settings.general.auto_increase_microphone_volume".localized,
                            tooltip: "settings.general.auto_increase_microphone_volume_tooltip".localized,
                            isOn: $viewModel.autoIncreaseMicrophoneVolume
                        )
                    }
                }

                // Sound Feedback
                MAGroup("settings.general.sound_feedback".localized, icon: "speaker.wave.2.fill") {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                        MAToggleRow(
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
            .frame(width: MeetingAssistantDesignSystem.Layout.smallPickerWidth)

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
