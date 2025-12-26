import Foundation

/// Represents the current state of the transcription service.
enum ServiceState: String, Codable, Equatable {
    case unknown = "unknown"
    case connecting = "connecting"
    case connected = "connected"
    case disconnected = "disconnected"
    case error = "error"
}

/// Represents the model loading state.
enum ModelState: String, Codable, Equatable {
    case unloaded = "unloaded"
    case downloading = "downloading"
    case loading = "loading"
    case loaded = "loaded"
    case error = "error"
}

/// Represents the transcription processing phase.
enum TranscriptionPhase: String, Codable, Equatable {
    case idle = "idle"
    case preparing = "preparing"
    case processing = "processing"
    case postProcessing = "post_processing"
    case completed = "completed"
    case failed = "failed"
}

/// Comprehensive status of the transcription system.
/// Tracks model, service, and transcription state for UI feedback.
@MainActor
class TranscriptionStatus: ObservableObject {
    // MARK: - Service State
    
    @Published private(set) var serviceState: ServiceState = .unknown
    @Published private(set) var modelState: ModelState = .unloaded
    @Published private(set) var device: String = "unknown"
    
    // MARK: - Transcription Progress
    
    @Published private(set) var phase: TranscriptionPhase = .idle
    @Published private(set) var progressPercentage: Double = 0.0
    @Published private(set) var estimatedTimeRemaining: TimeInterval?
    @Published private(set) var audioDurationSeconds: Double?
    @Published private(set) var processedDurationSeconds: Double = 0.0
    
    // MARK: - Error Tracking
    
    @Published private(set) var lastError: TranscriptionStatusError?
    @Published private(set) var lastErrorTime: Date?
    
    // MARK: - Timing
    
    @Published private(set) var transcriptionStartTime: Date?
    @Published private(set) var lastHealthCheck: Date?
    
    // MARK: - Computed Properties
    
    /// Returns user-friendly status message.
    var statusMessage: String {
        switch (serviceState, modelState, phase) {
        case (.disconnected, _, _):
            return "Serviço desconectado"
        case (.connecting, _, _):
            return "Conectando ao serviço..."
        case (.error, _, _):
            return lastError?.localizedDescription ?? "Erro de conexão"
        case (.connected, .downloading, _):
            return "Baixando modelo (isso pode demorar)..."
        case (.connected, .loading, _):
            return "Carregando modelo..."
        case (.connected, .error, _):
            return "Erro ao carregar modelo"
        case (.connected, .unloaded, _):
            return "Modelo não carregado"
        case (.connected, .loaded, .idle):
            return "Pronto para transcrever"
        case (.connected, .loaded, .preparing):
            return "Preparando áudio..."
        case (.connected, .loaded, .processing):
            return formattedProgress
        case (.connected, .loaded, .postProcessing):
            return "Processando resultado..."
        case (.connected, .loaded, .completed):
            return "Transcrição concluída!"
        case (.connected, .loaded, .failed):
            return lastError?.localizedDescription ?? "Falha na transcrição"
        default:
            return "Status desconhecido"
        }
    }
    
    /// Returns formatted progress string.
    private var formattedProgress: String {
        if let estimated = estimatedTimeRemaining, estimated > 0 {
            return "Transcrevendo... \(Int(progressPercentage))% (~\(TimeFormatter.format(estimated)) restante)"
        } else if progressPercentage > 0 {
            return "Transcrevendo... \(Int(progressPercentage))%"
        }
        return "Transcrevendo áudio..."
    }
    
    /// Whether system is ready for transcription.
    var isReady: Bool {
        serviceState == .connected && modelState == .loaded && phase == .idle
    }
    
    /// Whether transcription is currently in progress.
    var isProcessing: Bool {
        [.preparing, .processing, .postProcessing].contains(phase)
    }
    
    /// Whether there's a blocking error.
    var hasBlockingError: Bool {
        serviceState == .error || serviceState == .disconnected || modelState == .error
    }
    
    // MARK: - Update Methods
    
    /// Update service connection state.
    func updateServiceState(_ state: ServiceState) {
        serviceState = state
        if state == .connected {
            lastHealthCheck = Date()
        }
    }
    
    /// Update model loading state.
    func updateModelState(_ state: ModelState, device: String? = nil) {
        modelState = state
        if let device = device {
            self.device = device
        }
    }
    
    /// Begins a new transcription session.
    func beginTranscription(audioDuration: Double?) {
        phase = .preparing
        progressPercentage = 0.0
        estimatedTimeRemaining = nil
        audioDurationSeconds = audioDuration
        processedDurationSeconds = 0.0
        transcriptionStartTime = Date()
        lastError = nil
    }
    
    /// Updates transcription progress during processing.
    func updateProgress(
        phase: TranscriptionPhase,
        percentage: Double? = nil,
        processedSeconds: Double? = nil
    ) {
        self.phase = phase
        
        if let percentage = percentage {
            progressPercentage = min(max(percentage, 0.0), 100.0)
        }
        
        if let processed = processedSeconds {
            processedDurationSeconds = processed
            calculateEstimatedTime()
        }
    }
    
    /// Marks transcription as completed.
    func completeTranscription(success: Bool) {
        phase = success ? .completed : .failed
        progressPercentage = success ? 100.0 : progressPercentage
        estimatedTimeRemaining = nil
        transcriptionStartTime = nil
    }
    
    /// Resets to idle state after completion.
    func resetToIdle() {
        phase = .idle
        progressPercentage = 0.0
        estimatedTimeRemaining = nil
        audioDurationSeconds = nil
        processedDurationSeconds = 0.0
        transcriptionStartTime = nil
    }
    
    /// Records an error that occurred.
    func recordError(_ error: TranscriptionStatusError) {
        lastError = error
        lastErrorTime = Date()
        
        // Update state based on error type
        switch error {
        case .serviceUnavailable, .connectionFailed:
            serviceState = .disconnected
        case .modelLoadFailed:
            modelState = .error
        case .transcriptionFailed:
            phase = .failed
        }
    }
    
    /// Clears error state.
    func clearError() {
        lastError = nil
        lastErrorTime = nil
    }
    
    // MARK: - Private Methods
    
    /// Calculates estimated time remaining based on processing speed.
    private func calculateEstimatedTime() {
        guard let startTime = transcriptionStartTime,
              let audioDuration = audioDurationSeconds,
              processedDurationSeconds > 0 else {
            estimatedTimeRemaining = nil
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let processingSpeed = processedDurationSeconds / elapsed
        
        guard processingSpeed > 0 else {
            estimatedTimeRemaining = nil
            return
        }
        
        let remainingAudio = audioDuration - processedDurationSeconds
        estimatedTimeRemaining = remainingAudio / processingSpeed
        
        // Update percentage based on processed duration
        progressPercentage = (processedDurationSeconds / audioDuration) * 100.0
    }
}

// MARK: - Error Types

/// Errors related to transcription status.
enum TranscriptionStatusError: LocalizedError, Equatable {
    case serviceUnavailable
    case connectionFailed(String)
    case modelLoadFailed(String)
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Serviço de transcrição indisponível"
        case .connectionFailed(let reason):
            return "Falha na conexão: \(reason)"
        case .modelLoadFailed(let reason):
            return "Erro ao carregar modelo: \(reason)"
        case .transcriptionFailed(let reason):
            return "Falha na transcrição: \(reason)"
        }
    }
}
