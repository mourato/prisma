import SwiftUI
import UniformTypeIdentifiers

// MARK: - General Settings Tab

/// Tab for general app settings like recording preferences and monitored apps.
public struct GeneralSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @State private var draggingDevice: AudioInputDevice?
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                languageSection
                serviceSection
                recordingSection
                storageSection
                keyboardControlsSection
                transcriptDeliverySection
                recordingIndicatorSection
                audioDevicesSection
                appsSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
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

                HStack {
                    Text("settings.general.language".localized)
                        .font(.body)

                    Spacer()

                    Picker("", selection: $viewModel.selectedLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 200)
                    .accessibilityLabel("settings.general.language".localized)
                }
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
                SettingsToggle(
                    "settings.general.auto_start".localized,
                    isOn: $viewModel.autoStartRecording
                )

                Divider()

                SettingsToggle(
                    "settings.general.show_settings_on_launch".localized,
                    isOn: $viewModel.showSettingsOnLaunch
                )

                Divider()

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
                    .frame(width: 200)
                }

                // Merge Toggle
                SettingsToggle(
                    "settings.general.merge_audio".localized,
                    isOn: $viewModel.shouldMergeAudioFiles
                )
            }
        }
    }

    @ViewBuilder
    private var transcriptDeliverySection: some View {
        SettingsGroup("settings.general.transcript_delivery".localized, icon: "paperplane.fill") {
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
    }

    @ViewBuilder
    private var keyboardControlsSection: some View {
        RecordingKeyboardControlsSection(viewModel: shortcutsViewModel)
    }

    @ViewBuilder
    private var recordingIndicatorSection: some View {
        SettingsGroup("settings.general.recording_indicator".localized, icon: "waveform") {
            VStack(alignment: .leading, spacing: 16) {
                SettingsToggle(
                    "settings.general.recording_indicator.enabled".localized,
                    isOn: $viewModel.recordingIndicatorEnabled
                )

                if viewModel.recordingIndicatorEnabled {
                    Divider()

                    HStack {
                        Text("settings.general.recording_indicator.style".localized)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Picker("", selection: $viewModel.recordingIndicatorStyle) {
                            ForEach(RecordingIndicatorStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }

                    Divider()

                    HStack {
                        Text("settings.general.recording_indicator.position".localized)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Picker("", selection: $viewModel.recordingIndicatorPosition) {
                            ForEach(RecordingIndicatorPosition.allCases, id: \.self) { position in
                                Text(position.displayName).tag(position)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var storageSection: some View {
        SettingsGroup("settings.general.storage".localized, icon: "externaldrive.fill") {
            VStack(alignment: .leading, spacing: 16) {
                SettingsToggle(
                    "settings.general.auto_delete".localized,
                    description: "settings.general.auto_delete_desc".localized,
                    isOn: $viewModel.autoDeleteTranscriptions
                )

                if viewModel.autoDeleteTranscriptions {
                    Divider()

                        Picker("", selection: $viewModel.autoDeletePeriodDays) {
                            Text(String(format: NSLocalizedString("settings.general.days_format", bundle: .safeModule, comment: ""), 7)).tag(7)
                            Text(String(format: NSLocalizedString("settings.general.days_format", bundle: .safeModule, comment: ""), 14)).tag(14)
                            Text(String(format: NSLocalizedString("settings.general.days_format", bundle: .safeModule, comment: ""), 30)).tag(30)
                            Text(String(format: NSLocalizedString("settings.general.days_format", bundle: .safeModule, comment: ""), 90)).tag(90)
                            Text(String(format: NSLocalizedString("settings.general.days_format", bundle: .safeModule, comment: ""), 180)).tag(180)
                            Text(String(format: NSLocalizedString("settings.general.days_format", bundle: .safeModule, comment: ""), 365)).tag(365)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var audioDevicesSection: some View {
        SettingsGroup("settings.general.audio_devices".localized, icon: "mic.fill") {
            VStack(alignment: .leading, spacing: 12) {
                SettingsToggle(
                    "settings.general.use_system_default_input".localized,
                    description: "settings.general.use_system_default_input_desc".localized,
                    isOn: $viewModel.useSystemDefaultInput
                )

                if !viewModel.useSystemDefaultInput {
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
                }

                Divider()

                SettingsToggle(
                    "settings.general.mute_output_during_recording".localized,
                    description: "settings.general.mute_output_desc".localized,
                    isOn: $viewModel.muteOutputDuringRecording
                )
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
