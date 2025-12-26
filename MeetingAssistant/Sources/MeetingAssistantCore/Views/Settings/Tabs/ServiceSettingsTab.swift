import SwiftUI

// MARK: - Service Settings Tab

/// Tab for configuring local transcription service settings.
public struct ServiceSettingsTab: View {
    @StateObject private var viewModel = ServiceSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                self.modelInfoSection
                self.performanceSection
                self.statusSection
            }
            .padding()
        }
    }

    private var modelInfoSection: some View {
        SettingsGroup(NSLocalizedString("settings.service.model_info", comment: ""), icon: "waveform") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("settings.service.on_device", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("settings.service.ane_opt", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().padding(.vertical, 4)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    GridRow {
                        Text(NSLocalizedString("settings.service.model", comment: ""))
                            .foregroundStyle(.secondary)
                        Text("Parakeet TDT 0.6B v3")
                            .fontWeight(.medium)
                    }
                    GridRow {
                        Text(NSLocalizedString("settings.service.languages", comment: ""))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("settings.service.languages_desc", comment: ""))
                            .fontWeight(.medium)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var performanceSection: some View {
        SettingsCard {
            HStack(spacing: 12) {
                Image(systemName: "speedometer")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("settings.service.high_performance", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(NSLocalizedString("settings.service.no_internet", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var statusSection: some View {
        SettingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.service.status", comment: ""))
                        .font(.headline)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(self.viewModel.transcriptionStatus.color)
                            .frame(width: 8, height: 8)
                        Text(self.viewModel.transcriptionStatus.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: { self.viewModel.testConnection() }) {
                    if self.viewModel.transcriptionStatus == .testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(NSLocalizedString("settings.service.verify", comment: ""), systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(self.viewModel.transcriptionStatus == .testing)
            }
        }
    }
}

#Preview {
    ServiceSettingsTab()
}
