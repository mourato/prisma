import SwiftUI

/// Visual component showing transcription service status and progress.
/// Provides real-time feedback on model loading, service connection, and transcription progress.
public struct TranscriptionStatusView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var isExpanded = false

    public init(viewModel: TranscriptionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 8) {
            mainStatusRow

            if isExpanded {
                expandedDetails
            }
        }
        .padding(12)
        .background(statusBackground, in: RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
    }

    // MARK: - Main Status Row

    private var mainStatusRow: some View {
        HStack(spacing: 10) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(statusTextColor)

                if viewModel.isProcessing {
                    progressBar
                }
            }

            Spacer()

            chevronButton
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusIconBackground)
                .frame(width: 28, height: 28)

            statusIconImage
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusIconColor)
        }
    }

    private var statusIconImage: some View {
        Group {
            switch (viewModel.serviceState, viewModel.modelState, viewModel.phase) {
            case (.disconnected, _, _), (.error, _, _):
                Image(systemName: "xmark.circle.fill")
            case (.connecting, _, _):
                ProgressView()
                    .controlSize(.small)
            case (.connected, .downloading, _):
                ProgressView()
                    .controlSize(.small)
            case (.connected, .loading, _):
                ProgressView()
                    .controlSize(.small)
            case (.connected, .error, _):
                Image(systemName: "exclamationmark.triangle.fill")
            case (.connected, .unloaded, _):
                Image(systemName: "circle.dashed")
            case (_, _, .processing), (_, _, .preparing):
                ProgressView()
                    .controlSize(.small)
            case (_, _, .completed):
                Image(systemName: "checkmark.circle.fill")
            case (_, _, .failed):
                Image(systemName: "xmark.circle.fill")
            default:
                Image(systemName: "checkmark.circle.fill")
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    // Progress fill
                    Capsule()
                        .fill(progressGradient)
                        .frame(
                            width: max(
                                0, geometry.size.width * (viewModel.progressPercentage / 100.0)),
                            height: 4
                        )
                }
            }
            .frame(height: 4)

            if let remaining = viewModel.estimatedTimeRemaining, remaining > 0 {
                Text("~\(formatTime(remaining)) restante")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            detailRow(label: "Serviço", value: serviceStateLabel)
            detailRow(label: "Modelo", value: modelStateLabel)
            detailRow(label: "Dispositivo", value: viewModel.device.uppercased())

            if let error = viewModel.lastError {
                errorRow(error: error)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var serviceStateLabel: String {
        switch viewModel.serviceState {
        case .connected: return "Conectado"
        case .connecting: return "Conectando..."
        case .disconnected: return "Desconectado"
        case .error: return "Erro"
        case .unknown: return "Desconhecido"
        }
    }

    private var modelStateLabel: String {
        switch viewModel.modelState {
        case .loaded: return "Carregado"
        case .downloading: return "Baixando..."
        case .loading: return "Carregando..."
        case .unloaded: return "Não carregado"
        case .error: return "Erro ao carregar"
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func errorRow(error: TranscriptionStatusError) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error.errorDescription ?? "Erro desconhecido")
                .font(.caption)
                .foregroundStyle(.red)
        }
        .padding(6)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private var chevronButton: some View {
        Image(systemName: "chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
    }

    // MARK: - Styling Computed Properties

    private var statusBackground: some ShapeStyle {
        switch (viewModel.serviceState, viewModel.hasBlockingError) {
        case (_, true):
            return AnyShapeStyle(Color.red.opacity(0.1))
        case (.connected, _) where viewModel.isProcessing:
            return AnyShapeStyle(Color.blue.opacity(0.1))
        case (.connected, _) where viewModel.phase == .completed:
            return AnyShapeStyle(Color.green.opacity(0.1))
        default:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    private var statusTextColor: Color {
        if viewModel.hasBlockingError {
            return .red
        } else if viewModel.isProcessing {
            return .blue
        } else if viewModel.phase == .completed {
            return .green
        }
        return .primary
    }

    private var statusIconBackground: Color {
        if viewModel.hasBlockingError {
            return .red.opacity(0.15)
        } else if viewModel.isProcessing {
            return .blue.opacity(0.15)
        } else if viewModel.phase == .completed {
            return .green.opacity(0.15)
        } else if viewModel.isReady {
            return .green.opacity(0.15)
        }
        return .gray.opacity(0.15)
    }

    private var statusIconColor: Color {
        if viewModel.hasBlockingError {
            return .red
        } else if viewModel.isProcessing {
            return .blue
        } else if viewModel.phase == .completed || viewModel.isReady {
            return .green
        }
        return .gray
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        TimeFormatter.format(seconds)
    }
}

// MARK: - Compact Status View

/// Smaller status indicator for menu bar or compact displays.
public struct CompactTranscriptionStatusView: View {
    @ObservedObject var viewModel: TranscriptionViewModel

    public init(viewModel: TranscriptionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 6) {
            statusDot

            Text(compactStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .overlay {
                if viewModel.isProcessing || viewModel.modelState == .loading {
                    Circle()
                        .stroke(dotColor.opacity(0.5), lineWidth: 1)
                        .scaleEffect(1.5)
                        .opacity(viewModel.isProcessing ? 1 : 0)
                        .animation(
                            .easeInOut(duration: 1).repeatForever(), value: viewModel.isProcessing)
                }
            }
    }

    private var dotColor: Color {
        if viewModel.hasBlockingError {
            return .red
        } else if viewModel.isProcessing {
            return .blue
        } else if viewModel.isReady {
            return .green
        }
        return .yellow
    }

    private var compactStatusText: String {
        switch (viewModel.serviceState, viewModel.modelState, viewModel.phase) {
        case (.disconnected, _, _), (.error, _, _):
            return "Offline"
        case (.connecting, _, _):
            return "Conectando..."
        case (.connected, .downloading, _):
            return "Baixando modelo..."
        case (.connected, .loading, _):
            return "Carregando modelo..."
        case (.connected, .loaded, .idle):
            return "Pronto"
        case (.connected, .loaded, .processing):
            if viewModel.progressPercentage > 0 {
                return "Transcrevendo \(Int(viewModel.progressPercentage))%"
            }
            return "Transcrevendo..."
        case (.connected, .loaded, .completed):
            return "Concluído"
        default:
            return "Aguardando..."
        }
    }
}

#Preview("Full Status View") {
    let status = TranscriptionStatus()
    let viewModel = TranscriptionViewModel(status: status)

    VStack(spacing: 20) {
        TranscriptionStatusView(viewModel: viewModel)

        // Simulate different states
        Button("Ready") {
            Task { @MainActor in
                status.updateServiceState(.connected)
                status.updateModelState(.loaded, device: "mps")
                status.resetToIdle()
                // Force update on MainActor if needed, but bindings should handle it
            }
        }

        Button("Processing") {
            Task { @MainActor in
                status.beginTranscription(audioDuration: 120)
                status.updateProgress(phase: .processing, percentage: 45)
            }
        }

        Button("Error") {
            Task { @MainActor in
                status.recordError(.serviceUnavailable)
            }
        }
    }
    .padding()
    .frame(width: 300)
}

#Preview("Compact Status") {
    CompactTranscriptionStatusView(viewModel: TranscriptionViewModel(status: TranscriptionStatus()))
        .padding()
}
