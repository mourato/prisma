import SwiftUI

// MARK: - Service Settings Tab

/// Tab for configuring local transcription service settings.
public struct ServiceSettingsTab: View {
    @StateObject private var viewModel = ServiceSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                modelInfoSection
                performanceSection
                statusSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modelInfoSection: some View {
        SettingsGroup(NSLocalizedString("settings.service.model_info", bundle: .safeModule, comment: ""), icon: "waveform") {
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
                        Text(NSLocalizedString("settings.service.on_device", bundle: .safeModule, comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("settings.service.ane_opt", bundle: .safeModule, comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().padding(.vertical, 4)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    // ASR Model
                    GridRow {
                        Text(NSLocalizedString("settings.service.model", bundle: .safeModule, comment: ""))
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Parakeet TDT 0.6B v3")
                                    .fontWeight(.medium)
                                Text(modelStatusText)
                                    .font(.caption2)
                                    .foregroundStyle(modelStatusColor)
                            }

                            Spacer()

                            if viewModel.modelState == .loaded {
                                Button(role: .destructive) {
                                    viewModel.deleteASRModels()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .help("Delete Model")
                            } else if viewModel.modelState == .downloading || viewModel.modelState == .loading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button {
                                    viewModel.downloadASRModels()
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                                .help("Download Model")
                            }
                        }
                    }

                    Divider()

                    // Diarization Model
                    GridRow {
                        Text("Diarization")
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Pyannote 3.1")
                                    .fontWeight(.medium)
                                Text(viewModel.isDiarizationLoaded ? "Installed" : "Not Installed")
                                    .font(.caption2)
                                    .foregroundStyle(viewModel.isDiarizationLoaded ? .green : .secondary)
                            }

                            Spacer()

                            if viewModel.isDiarizationLoaded {
                                Button(role: .destructive) {
                                    viewModel.deleteDiarizationModels()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .help("Delete Model")
                            } else {
                                Button {
                                    Task { await FluidAIModelManager.shared.loadDiarizationModels() }
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                                .help("Download Model")
                            }
                        }
                    }

                    GridRow {
                        Text(NSLocalizedString("settings.service.languages", bundle: .safeModule, comment: ""))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("settings.service.languages_desc", bundle: .safeModule, comment: ""))
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
                    Text(NSLocalizedString("settings.service.high_performance", bundle: .safeModule, comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(NSLocalizedString("settings.service.no_internet", bundle: .safeModule, comment: ""))
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
                    Text(NSLocalizedString("settings.service.status", bundle: .safeModule, comment: ""))
                        .font(.headline)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.transcriptionStatus.color)
                            .frame(width: 8, height: 8)
                        Text(viewModel.transcriptionStatus.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: { viewModel.testConnection() }) {
                    if viewModel.transcriptionStatus == .testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(NSLocalizedString("settings.service.verify", bundle: .safeModule, comment: ""), systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.transcriptionStatus == .testing)
            }
        }
    }

    private var modelStatusText: String {
        switch viewModel.modelState {
        case .loaded: NSLocalizedString("transcription.model_state.loaded", bundle: .safeModule, comment: "")
        case .downloading: NSLocalizedString("transcription.model_state.downloading", bundle: .safeModule, comment: "")
        case .loading: NSLocalizedString("transcription.model_state.loading", bundle: .safeModule, comment: "")
        case .unloaded: NSLocalizedString("transcription.model_state.unloaded", bundle: .safeModule, comment: "")
        case .error: NSLocalizedString("transcription.model_state.error", bundle: .safeModule, comment: "")
        }
    }

    private var modelStatusColor: Color {
        switch viewModel.modelState {
        case .loaded: .green
        case .downloading, .loading: .orange
        case .unloaded, .error: .secondary
        }
    }
}

#Preview {
    ServiceSettingsTab()
}
