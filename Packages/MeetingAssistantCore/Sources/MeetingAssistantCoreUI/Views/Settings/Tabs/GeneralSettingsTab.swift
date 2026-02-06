import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - General Settings Tab

/// Main tab for core application settings like language, appearance, and storage.
public struct GeneralSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
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
                    }
                }

                // Appearance
                MAGroup("settings.general.appearance".localized, icon: "paintbrush.fill") {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                            Text("settings.general.theme_color".localized)
                                .font(.body)
                                .foregroundStyle(.primary)

                            MAThemePicker(selection: $viewModel.appAccentColor)
                        }

                        Divider()

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
                            .frame(width: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
                        }
                    }
                }

                // Recording Indicator
                MAGroup("settings.general.recording_indicator".localized, icon: "record.circle") {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                        MAToggleRow(
                            "settings.general.recording_indicator.enabled".localized,
                            description: "settings.general.recording_indicator.enabled_desc".localized,
                            isOn: $viewModel.recordingIndicatorEnabled
                        )

                        if viewModel.recordingIndicatorEnabled {
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
                                .frame(width: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
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
                                .frame(width: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
                            }
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
                            .frame(width: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
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
                                isOn: $viewModel.autoDeleteTranscriptions
                            )

                            if viewModel.autoDeleteTranscriptions {
                                HStack {
                                    Text("settings.general.keep_for".localized)
                                        .font(.body)

                                    Spacer()

                                    Stepper(value: $viewModel.autoDeletePeriodDays, in: 1...365) {
                                        Text("\(viewModel.autoDeletePeriodDays) " + "settings.general.days".localized)
                                            .font(.body)
                                            .monospacedDigit()
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
                        }
                    }
                }

                // AI Service
                ServiceSettingsContent()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
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
    }
}

#Preview {
    GeneralSettingsTab()
}
