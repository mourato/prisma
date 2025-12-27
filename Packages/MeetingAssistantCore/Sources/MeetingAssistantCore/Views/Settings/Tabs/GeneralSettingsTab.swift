import SwiftUI

// MARK: - General Settings Tab

/// Tab for general app settings like recording preferences and monitored apps.
public struct GeneralSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                self.languageSection
                self.recordingSection
                self.appsSection
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

                Picker("", selection: self.$viewModel.selectedLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
                .accessibilityLabel("settings.general.language".localized)

                if self.viewModel.selectedLanguage != .system {
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
                    isOn: self.$viewModel.autoStartRecording
                )

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.general.recordings_path".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField(
                            "settings.general.recordings_path_hint".localized,
                            text: self.$viewModel.recordingsPath
                        )
                        .textFieldStyle(.roundedBorder)

                        Button("settings.general.choose".localized) {
                            self.viewModel.selectRecordingsDirectory()
                        }
                    }
                }

                Divider()

                // Audio Format
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.general.audio_format".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("", selection: self.$viewModel.audioFormat) {
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
                    isOn: self.$viewModel.shouldMergeAudioFiles
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
}

#Preview {
    GeneralSettingsTab()
}
