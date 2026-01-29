import SwiftUI
import UniformTypeIdentifiers

// MARK: - General Settings Tab

/// Tab for general app settings like recording preferences and monitored apps.
public struct GeneralSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @State private var draggingDevice: AudioInputDevice?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                languageSection
                serviceSection
                recordingSection
                audioDevicesSection
                appsSection
            }
            .padding()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var languageSection: some View {
        SettingsGroup("settings.general.language".localized, icon: "globe") {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.general.language_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $viewModel.selectedLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
                .accessibilityLabel("settings.general.language".localized)

                if viewModel.selectedLanguage != .system {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("settings.general.language_restart_required".localized)
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var recordingSection: some View {
        SettingsGroup("settings.general.recording".localized, icon: "recordingtape") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(
                    "settings.general.auto_start".localized,
                    isOn: $viewModel.autoStartRecording
                )

                Divider()

                Toggle(
                    "settings.general.show_settings_on_launch".localized,
                    isOn: $viewModel.showSettingsOnLaunch
                )

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.general.recordings_path".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField(
                            "settings.general.recordings_path_hint".localized,
                            text: $viewModel.recordingsPath
                        )
                        .textFieldStyle(.roundedBorder)

                        Button("settings.general.choose".localized) {
                            viewModel.selectRecordingsDirectory()
                        }
                    }
                }

                Divider()

                // Audio Format
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.general.audio_format".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $viewModel.audioFormat) {
                        ForEach(AppSettingsStore.AudioFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden() // Label is above
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                }

                // Merge Toggle
                Toggle(
                    "settings.general.merge_audio".localized,
                    isOn: $viewModel.shouldMergeAudioFiles
                )
            }
        }
    }

    @ViewBuilder
    private var audioDevicesSection: some View {
        SettingsGroup("settings.general.audio_devices".localized, icon: "mic.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.general.audio_devices_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(viewModel.availableDevices) { device in
                        HStack(spacing: 12) {
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
                                    .foregroundStyle(.red)
                            }

                            Image(systemName: "line.3.horizontal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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

                Divider()

                Toggle(
                    "settings.general.mute_output_during_recording".localized,
                    isOn: $viewModel.muteOutputDuringRecording
                )
                .font(.body)

                Text("settings.general.mute_output_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var appsSection: some View {
        SettingsGroup("settings.general.monitored_apps".localized, icon: "app.badge") {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.general.monitored_apps_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(MeetingApp.allCases, id: \.self) { app in
                    HStack(spacing: 12) {
                        Image(systemName: app.icon)
                            .font(.title3)
                            .foregroundStyle(app.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("settings.general.monitoring_active".localized)
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                        Spacer()
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var serviceSection: some View {
        ServiceSettingsTab()
    }
}

#Preview {
    GeneralSettingsTab()
}

// MARK: - Drop Delegate (Issue #35)

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
