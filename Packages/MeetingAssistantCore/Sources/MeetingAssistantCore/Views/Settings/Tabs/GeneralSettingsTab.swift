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
        SettingsGroup(NSLocalizedString("settings.general.language", bundle: .safeModule, comment: ""), icon: "globe") {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("settings.general.language_desc", bundle: .safeModule, comment: ""))
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

                if self.viewModel.selectedLanguage != .system {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text(NSLocalizedString("settings.general.language_restart_required", bundle: .safeModule, comment: ""))
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var recordingSection: some View {
        SettingsGroup(NSLocalizedString("settings.general.recording", bundle: .safeModule, comment: ""), icon: "recordingtape") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(
                    NSLocalizedString("settings.general.auto_start", bundle: .safeModule, comment: ""),
                    isOn: self.$viewModel.autoStartRecording
                )

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.general.recordings_path", bundle: .safeModule, comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField(
                            NSLocalizedString("settings.general.recordings_path_hint", bundle: .safeModule, comment: "Caminho"),
                            text: self.$viewModel.recordingsPath
                        )
                        .textFieldStyle(.roundedBorder)

                        Button(NSLocalizedString("settings.general.choose", bundle: .safeModule, comment: "")) {
                            self.viewModel.selectRecordingsDirectory()
                        }
                    }
                }

                Divider()

                // Audio Format
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.general.audio_format", bundle: .safeModule, comment: "Formato de Áudio"))
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
                    NSLocalizedString("settings.general.merge_audio", bundle: .safeModule, comment: "Mesclar áudio (Mic + Sistema)"),
                    isOn: self.$viewModel.shouldMergeAudioFiles
                )
            }
        }
    }

    @ViewBuilder
    private var appsSection: some View {
        SettingsGroup(NSLocalizedString("settings.general.monitored_apps", bundle: .safeModule, comment: ""), icon: "app.badge") {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("settings.general.monitored_apps_desc", bundle: .safeModule, comment: ""))
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
                            Text(NSLocalizedString("settings.general.monitoring_active", bundle: .safeModule, comment: ""))
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
