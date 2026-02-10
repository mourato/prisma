import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public struct ServiceSettingsContent: View {
    @StateObject private var viewModel: ServiceSettingsViewModel
    private let runInitialTasks: Bool

    public init(
        viewModel: ServiceSettingsViewModel = ServiceSettingsViewModel(),
        runInitialTasks: Bool = !PreviewRuntime.isRunning
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.runInitialTasks = runInitialTasks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
            modelInfoSection
            performanceSection
            statusSection
        }
        .task {
            guard runInitialTasks else { return }
            viewModel.refreshInstalledModelStates()
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
                    GridRow {
                        Text("settings.service.model".localized)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("settings.service.asr_model_name".localized)
                                    .fontWeight(.medium)
                                Text(asrStatusText)
                                    .font(.caption2)
                                    .foregroundStyle(asrStatusColor)
                            }

                            Spacer()

                            if viewModel.modelState == .downloading || viewModel.modelState == .loading {
                                ProgressView()
                                    .controlSize(.small)
                            } else if viewModel.isASRInstalled {
                                Button(role: .destructive) {
                                    viewModel.deleteASRModels()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
                                }
                                .buttonStyle(.borderless)
                                .help("settings.service.delete_model".localized)
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
                                    viewModel.downloadDiarizationModels()
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

    private var asrStatusText: String {
        switch viewModel.modelState {
        case .loaded: "settings.service.installed".localized
        case .downloading: "transcription.model_state.downloading".localized
        case .loading: "transcription.model_state.loading".localized
        case .unloaded: viewModel.isASRInstalled ? "settings.service.installed".localized : "settings.service.not_installed".localized
        case .error: "transcription.model_state.error".localized
        }
    }

    private var asrStatusColor: Color {
        switch viewModel.modelState {
        case .loaded: MeetingAssistantDesignSystem.Colors.success
        case .downloading, .loading: MeetingAssistantDesignSystem.Colors.warning
        case .unloaded:
            viewModel.isASRInstalled ? MeetingAssistantDesignSystem.Colors.success : .secondary
        case .error:
            .secondary
        }
    }
}

@MainActor
private struct ServiceSettingsContentPreview: View {
    @StateObject private var viewModel: ServiceSettingsViewModel

    init() {
        let viewModel = ServiceSettingsViewModel()
        viewModel.transcriptionStatus = .success
        viewModel.modelState = .loaded
        viewModel.isASRInstalled = true
        viewModel.isDiarizationLoaded = true
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ServiceSettingsContent(viewModel: viewModel, runInitialTasks: false)
            .padding()
            .frame(width: 760)
    }
}

#Preview("Service Settings Content") {
    ServiceSettingsContentPreview()
}
