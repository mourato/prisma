import SwiftUI

// MARK: - Service Settings Tab

/// Tab for configuring local transcription service settings.
public struct ServiceSettingsTab: View {
    @StateObject private var viewModel = ServiceSettingsViewModel()

    @MainActor
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                modelInfoSection
                performanceSection
                statusSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            viewModel.testConnection()
        }
    }

    private var modelInfoSection: some View {
        MAGroup("settings.service.model_info".localized, icon: "waveform") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                    ZStack {
                        Circle()
                            .fill(MeetingAssistantDesignSystem.Colors.accent.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.service.on_device".localized)
                            .font(.headline)
                        Text("settings.service.ane_opt".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing4)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    // ASR Model
                    GridRow {
                        Text("settings.service.model".localized)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("settings.service.asr_model_name".localized)
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
                                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
                                }
                                .buttonStyle(.borderless)
                                .help("settings.service.delete_model".localized)
                            } else if viewModel.modelState == .downloading || viewModel.modelState == .loading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button {
                                    viewModel.downloadASRModels()
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.title3)
                                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                                }
                                .buttonStyle(.borderless)
                                .help("settings.service.download_model".localized)
                            }
                        }
                    }

                    Divider()

                    // Diarization Model
                    GridRow {
                        Text("settings.service.diarization".localized)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("settings.service.diarization_model_name".localized)
                                    .fontWeight(.medium)
                                Text(
                                    viewModel.isDiarizationLoaded
                                        ? "settings.service.installed".localized
                                        : "settings.service.not_installed".localized
                                )
                                .font(.caption2)
                                .foregroundStyle(viewModel.isDiarizationLoaded ? MeetingAssistantDesignSystem.Colors.success : .secondary)
                            }

                            Spacer()

                            if viewModel.isDiarizationLoaded {
                                Button(role: .destructive) {
                                    viewModel.deleteDiarizationModels()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
                                }
                                .buttonStyle(.borderless)
                                .help("settings.service.delete_model".localized)
                            } else {
                                Button {
                                    Task { await FluidAIModelManager.shared.loadDiarizationModels() }
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.title3)
                                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                                }
                                .buttonStyle(.borderless)
                                .help("settings.service.download_model".localized)
                            }
                        }
                    }

                    GridRow {
                        Text("settings.service.languages".localized)
                            .foregroundStyle(.secondary)
                        Text("settings.service.languages_desc".localized)
                            .fontWeight(.medium)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var performanceSection: some View {
        MACard {
            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                Image(systemName: "speedometer")
                    .font(.title3)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.service.high_performance".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("settings.service.no_internet".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var statusSection: some View {
        MACard {
            HStack {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Text("settings.service.status".localized)
                        .font(.headline)

                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                        Circle()
                            .fill(viewModel.transcriptionStatus.color)
                            .frame(width: 8, height: 8)
                        Text(viewModel.transcriptionStatus.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(
                    action: { viewModel.testConnection() },
                    label: {
                        if viewModel.transcriptionStatus == .testing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(
                                "settings.service.verify".localized,
                                systemImage: "arrow.clockwise"
                            )
                        }
                    }
                )
                .buttonStyle(.bordered)
                .disabled(viewModel.transcriptionStatus == .testing)
            }
        }
    }

    private var modelStatusText: String {
        switch viewModel.modelState {
        case .loaded: "transcription.model_state.loaded".localized
        case .downloading: "transcription.model_state.downloading".localized
        case .loading: "transcription.model_state.loading".localized
        case .unloaded: "transcription.model_state.unloaded".localized
        case .error: "transcription.model_state.error".localized
        }
    }

    private var modelStatusColor: Color {
        switch viewModel.modelState {
        case .loaded: MeetingAssistantDesignSystem.Colors.success
        case .downloading, .loading: MeetingAssistantDesignSystem.Colors.warning
        case .unloaded, .error: .secondary
        }
    }
}

#Preview {
    ServiceSettingsTab()
}
