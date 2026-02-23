import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - General Settings Tab

/// Main tab for core application settings like language, appearance, and storage.
public struct GeneralSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @State private var shortcutDoubleTapIntervalInput = ""
    @State private var autoDeletePeriodDaysInput = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.general.title".localized,
                description: "settings.general.language_desc".localized
            )

            // Application Behavior
            MAGroup("settings.general.app_behavior".localized, icon: "app.badge") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    MAToggleRow(
                        "settings.general.launch_at_login".localized,
                        isOn: $viewModel.launchAtLogin
                    )

                    Divider()

                    MAToggleRow(
                        "settings.general.show_in_dock".localized,
                        description: "settings.general.show_in_dock_desc".localized,
                        isOn: $viewModel.showInDock
                    )

                    Divider()

                    MAToggleRow(
                        "settings.general.show_settings_on_launch".localized,
                        isOn: $viewModel.showSettingsOnLaunch
                    )

                    Divider()

                    HStack(alignment: .center, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                            Text("settings.general.shortcut_double_tap_interval".localized)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Text("settings.general.shortcut_double_tap_interval_desc".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                            TextField("", text: $shortcutDoubleTapIntervalInput)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 84)
                                .onChange(of: shortcutDoubleTapIntervalInput) { _, newValue in
                                    applyShortcutDoubleTapIntervalInput(newValue)
                                }
                                .onSubmit {
                                    syncShortcutDoubleTapIntervalInputFromModel()
                                }

                            Text("ms")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Appearance
            MAGroup("settings.general.appearance".localized, icon: "paintbrush.fill") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    HStack {
                        Text("settings.general.language".localized)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Picker("", selection: $viewModel.selectedLanguage) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }

            // Recording Indicator
            MAGroup("settings.general.recording_indicator".localized, icon: "record.circle") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    MAToggleRow(
                        "settings.general.recording_indicator.enabled".localized,
                        description: "settings.general.recording_indicator.enabled_desc".localized,
                        isOn: $viewModel.recordingIndicatorEnabled.animated()
                    )

                    if viewModel.recordingIndicatorEnabled {
                        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
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
                        }
                        .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
                    }
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
                    }
                }
            }

            // Storage
            MAGroup("settings.general.storage".localized, icon: "folder.fill") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                        MAToggleRow(
                            "settings.general.auto_delete".localized,
                            description: "settings.general.auto_delete_desc".localized,
                            isOn: $viewModel.autoDeleteTranscriptions.animated()
                        )

                        if viewModel.autoDeleteTranscriptions {
                            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                                HStack {
                                    Text("settings.general.keep_for".localized)
                                        .font(.body)

                                    Spacer()

                                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                                        TextField("", text: $autoDeletePeriodDaysInput)
                                            .textFieldStyle(.roundedBorder)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 84)
                                            .onChange(of: autoDeletePeriodDaysInput) { _, newValue in
                                                applyAutoDeletePeriodDaysInput(newValue)
                                            }
                                            .onSubmit {
                                                syncAutoDeletePeriodDaysInputFromModel()
                                            }

                                        Text("settings.general.days".localized)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.leading, MeetingAssistantDesignSystem.Layout.indentation)

                                Button {
                                    viewModel.performCleanup()
                                } label: {
                                    Text(String(
                                        format: "settings.storage.cleanup_now".localized,
                                        viewModel.autoDeletePeriodDays
                                    ))
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.cleanupInProgress)
                                .padding(.leading, MeetingAssistantDesignSystem.Layout.indentation)
                                .padding(.top, MeetingAssistantDesignSystem.Layout.smallPadding)
                            }
                            .transition(SettingsMotion.sectionTransition(reduceMotion: reduceMotion))
                        }
                    }
                }
            }

            // AI Service
            ServiceSettingsContent()
        }
        .confirmationDialog(
            "settings.storage.cleanup_confirm_title".localized,
            isPresented: $viewModel.showCleanupConfirmationDialog,
            titleVisibility: .visible
        ) {
            Button("settings.storage.cleanup_confirm_delete".localized, role: .destructive) {
                viewModel.confirmCleanup()
            }
            Button("settings.storage.cleanup_confirm_cancel".localized, role: .cancel) {}
        } message: {
            Text(viewModel.cleanupConfirmationMessage)
        }
        .alert("settings.general.storage".localized, isPresented: $viewModel.showCleanupSuccessAlert) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text("settings.storage.cleanup_success".localized)
        }
        .alert("common.error".localized, isPresented: Binding(
            get: { viewModel.cleanupError != nil },
            set: { if !$0 { viewModel.cleanupError = nil } }
        )) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            if let error = viewModel.cleanupError {
                Text(error)
            }
        }
        .onAppear {
            syncShortcutDoubleTapIntervalInputFromModel()
            syncAutoDeletePeriodDaysInputFromModel()
        }
    }

    private func applyShortcutDoubleTapIntervalInput(_ rawValue: String) {
        let digitsOnly = rawValue.filter(\.isNumber)
        if digitsOnly != rawValue {
            shortcutDoubleTapIntervalInput = digitsOnly
            return
        }

        guard !digitsOnly.isEmpty, let value = Double(digitsOnly) else { return }
        let validRange = AppSettingsStore.shortcutDoubleTapIntervalRangeMilliseconds
        let clampedValue = min(max(value, validRange.lowerBound), validRange.upperBound)

        viewModel.shortcutDoubleTapIntervalMilliseconds = clampedValue
        let normalizedValue = "\(Int(clampedValue))"
        if shortcutDoubleTapIntervalInput != normalizedValue {
            shortcutDoubleTapIntervalInput = normalizedValue
        }
    }

    private func syncShortcutDoubleTapIntervalInputFromModel() {
        shortcutDoubleTapIntervalInput = "\(Int(viewModel.shortcutDoubleTapIntervalMilliseconds))"
    }

    private func applyAutoDeletePeriodDaysInput(_ rawValue: String) {
        let digitsOnly = rawValue.filter(\.isNumber)
        if digitsOnly != rawValue {
            autoDeletePeriodDaysInput = digitsOnly
            return
        }

        guard !digitsOnly.isEmpty, let value = Int(digitsOnly) else { return }
        let clampedValue = min(max(value, 1), 365)

        viewModel.autoDeletePeriodDays = clampedValue
        let normalizedValue = "\(clampedValue)"
        if autoDeletePeriodDaysInput != normalizedValue {
            autoDeletePeriodDaysInput = normalizedValue
        }
    }

    private func syncAutoDeletePeriodDaysInputFromModel() {
        autoDeletePeriodDaysInput = "\(viewModel.autoDeletePeriodDays)"
    }
}

#Preview {
    GeneralSettingsTab()
}
