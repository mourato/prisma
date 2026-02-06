import SwiftUI

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
                    }
                }

                // Audio Format
                MAGroup("settings.general.audio_format".localized, icon: "waveform.path") {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                        HStack {
                            Text("settings.general.audio_format".localized)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Picker("", selection: $viewModel.audioFormat) {
                                ForEach(AppSettingsStore.AudioFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
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
