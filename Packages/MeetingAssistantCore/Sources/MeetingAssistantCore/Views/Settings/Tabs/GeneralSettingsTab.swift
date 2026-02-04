import SwiftUI

// MARK: - General Settings Tab

/// Main tab for core application settings like language, appearance, and storage.
public struct GeneralSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                // Application Behavior
                SettingsGroup("settings.general.app_behavior".localized, icon: "app.badge") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
                            "settings.general.launch_at_login".localized,
                            isOn: $viewModel.launchAtLogin
                        )

                        Divider()

                        SettingsToggle(
                            "settings.general.show_in_dock".localized,
                            description: "settings.general.show_in_dock_desc".localized,
                            isOn: $viewModel.showInDock
                        )

                        Divider()

                        SettingsToggle(
                            "settings.general.show_settings_on_launch".localized,
                            isOn: $viewModel.showSettingsOnLaunch
                        )
                    }
                }

                // Appearance
                SettingsGroup("settings.general.appearance".localized, icon: "paintbrush.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.general.theme_color".localized)
                                .font(.body)
                                .foregroundStyle(.primary)

                            SettingsThemePicker(selection: $viewModel.appAccentColor)
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
                            .frame(width: SettingsDesignSystem.Layout.maxPickerWidth)
                        }
                    }
                }

                // Recording Indicator
                SettingsGroup("settings.general.recording_indicator".localized, icon: "record.circle") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
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
                                .frame(width: 200)
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
                                .frame(width: 200)
                            }
                        }
                    }
                }

                // Storage
                SettingsGroup("settings.general.storage".localized, icon: "folder.fill") {
                    VStack(alignment: .leading, spacing: 16) {

                        VStack(alignment: .leading, spacing: 12) {
                            SettingsToggle(
                                "settings.general.auto_delete".localized,
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
                                .padding(.leading, SettingsDesignSystem.Layout.indentation)

                                Button {
                                    viewModel.performCleanup()
                                } label: {
                                    Text("settings.storage.cleanup_now".localized)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .padding(.leading, SettingsDesignSystem.Layout.indentation)
                                .padding(.top, SettingsDesignSystem.Layout.smallPadding)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("settings.general.storage".localized, isPresented: $viewModel.showCleanupSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("settings.storage.cleanup_success".localized)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.cleanupError != nil },
            set: { if !$0 { viewModel.cleanupError = nil } }
        )) {
            Button("OK", role: .cancel) {}
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
