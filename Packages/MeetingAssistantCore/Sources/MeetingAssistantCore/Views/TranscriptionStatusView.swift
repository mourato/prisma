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
            self.mainStatusRow

            if self.isExpanded {
                self.expandedDetails
            }
        }
        .padding(12)
        .background(self.statusBackground, in: RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.2), value: self.isExpanded)
        .animation(.easeInOut(duration: 0.3), value: self.viewModel.phase)
    }

    // MARK: - Main Status Row

    private var mainStatusRow: some View {
        HStack(spacing: 10) {
            self.statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(self.viewModel.statusMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(self.statusTextColor)

                if self.viewModel.isProcessing {
                    self.progressBar
                }
            }

            Spacer()

            self.chevronButton
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                self.isExpanded.toggle()
            }
        }
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(self.statusIconBackground)
                .frame(width: 28, height: 28)

            self.statusIconImage
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(self.statusIconColor)
        }
    }

    private var statusIconImage: some View {
        Group {
            switch (self.viewModel.serviceState, self.viewModel.modelState, self.viewModel.phase) {
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
                        .fill(self.progressGradient)
                        .frame(
                            width: max(
                                0, geometry.size.width * (self.viewModel.progressPercentage / 100.0)
                            ),
                            height: 4
                        )
                }
            }
            .frame(height: 4)

            if let remaining = viewModel.estimatedTimeRemaining, remaining > 0 {
                Text("transcription.time_remaining".localized(with: self.formatTime(remaining)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            self.detailRow(label: "transcription.service".localized, value: self.serviceStateLabel)
            self.detailRow(label: "transcription.model".localized, value: self.modelStateLabel)
            self.detailRow(label: "transcription.device".localized, value: self.viewModel.device.uppercased())

            if let error = viewModel.lastError {
                self.errorRow(error: error)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var serviceStateLabel: String {
        switch self.viewModel.serviceState {
        case .connected: "transcription.state.connected".localized
        case .connecting: "transcription.state.connecting".localized
        case .disconnected: "transcription.state.disconnected".localized
        case .error: "transcription.state.error".localized
        case .unknown: "transcription.state.unknown".localized
        }
    }

    private var modelStateLabel: String {
        switch self.viewModel.modelState {
        case .loaded: "transcription.model_state.loaded".localized
        case .downloading: "transcription.model_state.downloading".localized
        case .loading: "transcription.model_state.loading".localized
        case .unloaded: "transcription.model_state.unloaded".localized
        case .error: "transcription.model_state.error".localized
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

            VStack(alignment: .leading) {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                Text("transcription.error.click_retry".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private var chevronButton: some View {
        Image(systemName: "chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(self.isExpanded ? 180 : 0))
            .accessibilityLabel("transcription.view.toggle_details".localized)
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Styling Computed Properties

    private var statusBackground: some ShapeStyle {
        switch (self.viewModel.serviceState, self.viewModel.hasBlockingError) {
        case (_, true):
            AnyShapeStyle(Color.red.opacity(0.1))
        case (.connected, _) where self.viewModel.isProcessing:
            AnyShapeStyle(Color.blue.opacity(0.1))
        case (.connected, _) where self.viewModel.phase == .completed:
            AnyShapeStyle(Color.green.opacity(0.1))
        default:
            AnyShapeStyle(.ultraThinMaterial)
        }
    }

    private var statusTextColor: Color {
        if self.viewModel.hasBlockingError {
            return .red
        } else if self.viewModel.isProcessing {
            return .blue
        } else if self.viewModel.phase == .completed {
            return .green
        }
        return .primary
    }

    private var statusIconBackground: Color {
        if self.viewModel.hasBlockingError {
            return .red.opacity(0.15)
        } else if self.viewModel.isProcessing {
            return .blue.opacity(0.15)
        } else if self.viewModel.phase == .completed {
            return .green.opacity(0.15)
        } else if self.viewModel.isReady {
            return .green.opacity(0.15)
        }
        return .gray.opacity(0.15)
    }

    private var statusIconColor: Color {
        if self.viewModel.hasBlockingError {
            return .red
        } else if self.viewModel.isProcessing {
            return .blue
        } else if self.viewModel.phase == .completed || self.viewModel.isReady {
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
            self.statusDot

            Text(self.compactStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(self.dotColor)
            .frame(width: 8, height: 8)
            .overlay {
                if self.viewModel.isProcessing || self.viewModel.modelState == .loading {
                    Circle()
                        .stroke(self.dotColor.opacity(0.5), lineWidth: 1)
                        .scaleEffect(1.5)
                        .opacity(self.viewModel.isProcessing ? 1 : 0)
                }
            }
    }

    private var dotColor: Color {
        if self.viewModel.hasBlockingError {
            return .red
        } else if self.viewModel.isProcessing {
            return .blue
        } else if self.viewModel.isReady {
            return .green
        }
        return .yellow
    }

    private var compactStatusText: String {
        switch (self.viewModel.serviceState, self.viewModel.modelState, self.viewModel.phase) {
        case (.disconnected, _, _), (.error, _, _):
            return "transcription.compact.offline".localized
        case (.connecting, _, _):
            return "transcription.compact.connecting".localized
        case (.connected, .downloading, _):
            return "transcription.compact.downloading_model".localized
        case (.connected, .loading, _):
            return "transcription.compact.loading_model".localized
        case (.connected, .loaded, .idle):
            return "transcription.compact.ready".localized
        case (.connected, .loaded, .processing):
            if self.viewModel.progressPercentage > 0 {
                return "transcription.compact.transcribing_percent"
                    .localized(with: Int(self.viewModel.progressPercentage))
            }
            return "transcription.compact.transcribing".localized
        case (.connected, .loaded, .completed):
            return "transcription.compact.completed".localized
        default:
            return "transcription.compact.waiting".localized
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
