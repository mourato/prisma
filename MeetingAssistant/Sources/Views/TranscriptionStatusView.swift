import SwiftUI

/// Visual component showing transcription service status and progress.
/// Provides real-time feedback on model loading, service connection, and transcription progress.
struct TranscriptionStatusView: View {
    @ObservedObject var status: TranscriptionStatus
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            mainStatusRow
            
            if isExpanded {
                expandedDetails
            }
        }
        .padding(12)
        .background(statusBackground, in: RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .animation(.easeInOut(duration: 0.3), value: status.phase)
    }
    
    // MARK: - Main Status Row
    
    private var mainStatusRow: some View {
        HStack(spacing: 10) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(status.statusMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(statusTextColor)
                
                if status.isProcessing {
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
            switch (status.serviceState, status.modelState, status.phase) {
            case (.disconnected, _, _), (.error, _, _):
                Image(systemName: "xmark.circle.fill")
            case (.connecting, _, _):
                ProgressView()
                    .scaleEffect(0.6)
            case (.connected, .loading, _):
                ProgressView()
                    .scaleEffect(0.6)
            case (.connected, .error, _):
                Image(systemName: "exclamationmark.triangle.fill")
            case (.connected, .unloaded, _):
                Image(systemName: "circle.dashed")
            case (_, _, .processing), (_, _, .preparing):
                ProgressView()
                    .scaleEffect(0.6)
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
                            width: max(0, geometry.size.width * (status.progressPercentage / 100.0)),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
            
            if let remaining = status.estimatedTimeRemaining, remaining > 0 {
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
            detailRow(label: "Dispositivo", value: status.device.uppercased())
            
            if let error = status.lastError {
                errorRow(error: error)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var serviceStateLabel: String {
        switch status.serviceState {
        case .connected: return "Conectado"
        case .connecting: return "Conectando..."
        case .disconnected: return "Desconectado"
        case .error: return "Erro"
        case .unknown: return "Desconhecido"
        }
    }
    
    private var modelStateLabel: String {
        switch status.modelState {
        case .loaded: return "Carregado"
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
        switch (status.serviceState, status.hasBlockingError) {
        case (_, true):
            return AnyShapeStyle(Color.red.opacity(0.1))
        case (.connected, _) where status.isProcessing:
            return AnyShapeStyle(Color.blue.opacity(0.1))
        case (.connected, _) where status.phase == .completed:
            return AnyShapeStyle(Color.green.opacity(0.1))
        default:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
    
    private var statusTextColor: Color {
        if status.hasBlockingError {
            return .red
        } else if status.isProcessing {
            return .blue
        } else if status.phase == .completed {
            return .green
        }
        return .primary
    }
    
    private var statusIconBackground: Color {
        if status.hasBlockingError {
            return .red.opacity(0.15)
        } else if status.isProcessing {
            return .blue.opacity(0.15)
        } else if status.phase == .completed {
            return .green.opacity(0.15)
        } else if status.isReady {
            return .green.opacity(0.15)
        }
        return .gray.opacity(0.15)
    }
    
    private var statusIconColor: Color {
        if status.hasBlockingError {
            return .red
        } else if status.isProcessing {
            return .blue
        } else if status.phase == .completed || status.isReady {
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
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Compact Status View

/// Smaller status indicator for menu bar or compact displays.
struct CompactTranscriptionStatusView: View {
    @ObservedObject var status: TranscriptionStatus
    
    var body: some View {
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
                if status.isProcessing || status.modelState == .loading {
                    Circle()
                        .stroke(dotColor.opacity(0.5), lineWidth: 1)
                        .scaleEffect(1.5)
                        .opacity(status.isProcessing ? 1 : 0)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: status.isProcessing)
                }
            }
    }
    
    private var dotColor: Color {
        if status.hasBlockingError {
            return .red
        } else if status.isProcessing {
            return .blue
        } else if status.isReady {
            return .green
        }
        return .yellow
    }
    
    private var compactStatusText: String {
        switch (status.serviceState, status.modelState, status.phase) {
        case (.disconnected, _, _), (.error, _, _):
            return "Offline"
        case (.connecting, _, _):
            return "Conectando..."
        case (.connected, .loading, _):
            return "Carregando modelo..."
        case (.connected, .loaded, .idle):
            return "Pronto"
        case (.connected, .loaded, .processing):
            if status.progressPercentage > 0 {
                return "Transcrevendo \(Int(status.progressPercentage))%"
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
    
    VStack(spacing: 20) {
        TranscriptionStatusView(status: status)
        
        // Simulate different states
        Button("Ready") {
            Task { @MainActor in
                status.updateServiceState(.connected)
                status.updateModelState(.loaded, device: "mps")
                status.resetToIdle()
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
    CompactTranscriptionStatusView(status: TranscriptionStatus())
        .padding()
}
