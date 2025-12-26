import SwiftUI

// MARK: - General Settings Tab

/// Tab for general app settings like recording preferences and monitored apps.
public struct GeneralSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                self.recordingSection
                self.appsSection
            }
            .padding()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var recordingSection: some View {
        SettingsGroup(NSLocalizedString("settings.general.recording", bundle: .module, comment: ""), icon: "recordingtape") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(
                    NSLocalizedString("settings.general.auto_start", bundle: .module, comment: ""),
                    isOn: self.$viewModel.autoStartRecording
                )

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.general.recordings_path", bundle: .module, comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField(
                            NSLocalizedString("settings.general.recordings_path_hint", bundle: .module, comment: "Caminho"),
                            text: self.$viewModel.recordingsPath
                        )
                        .textFieldStyle(.roundedBorder)

                        Button(NSLocalizedString("settings.general.choose", bundle: .module, comment: "")) {
                            self.viewModel.selectRecordingsDirectory()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var appsSection: some View {
        SettingsGroup(NSLocalizedString("settings.general.monitored_apps", bundle: .module, comment: ""), icon: "app.badge") {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("settings.general.monitored_apps_desc", bundle: .module, comment: ""))
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
                            Text(NSLocalizedString("settings.general.monitoring_active", bundle: .module, comment: ""))
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
