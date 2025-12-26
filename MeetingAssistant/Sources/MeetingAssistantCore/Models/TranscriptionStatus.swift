import Foundation

/// Represents the current state of the transcription service.
public enum ServiceState: String, Codable, Equatable {
    case unknown
    case connecting
    case connected
    case disconnected
    case error
}

/// Represents the model loading state.
public enum ModelState: String, Codable, Equatable {
    case unloaded
    case downloading
    case loading
    case loaded
    case error
}

/// Represents the transcription processing phase.
public enum TranscriptionPhase: String, Codable, Equatable {
    case idle
    case preparing
    case processing
    case postProcessing = "post_processing"
    case completed
    case failed
}

/// Comprehensive status of the transcription system.
@MainActor
public class TranscriptionStatus: ObservableObject {
    // MARK: - Service State

    @Published public private(set) var serviceState: ServiceState = .unknown
    @Published public private(set) var modelState: ModelState = .unloaded
    @Published public private(set) var device: String = "unknown"

    // MARK: - Transcription Progress

    @Published public private(set) var phase: TranscriptionPhase = .idle
    @Published public private(set) var progressPercentage: Double = 0.0
    @Published public private(set) var estimatedTimeRemaining: TimeInterval?
    @Published public private(set) var audioDurationSeconds: Double?
    @Published public private(set) var processedDurationSeconds: Double = 0.0

    // MARK: - Error Tracking

    @Published public private(set) var lastError: TranscriptionStatusError?
    @Published public private(set) var lastErrorTime: Date?

    // MARK: - Timing

    @Published public private(set) var transcriptionStartTime: Date?
    @Published public private(set) var lastHealthCheck: Date?

    public init() {}

    // MARK: - Computed Properties

    /// Returns user-friendly status message.
    public var statusMessage: String {
        switch (self.serviceState, self.modelState, self.phase) {
        case (.disconnected, _, _):
            "Serviço desconectado"
        case (.connecting, _, _):
            "Conectando ao serviço..."
        case (.error, _, _):
            self.lastError?.localizedDescription ?? "Erro de conexão"
        case (.connected, .downloading, _):
            "Baixando modelo (isso pode demorar)..."
        case (.connected, .loading, _):
            "Carregando modelo..."
        case (.connected, .error, _):
            "Erro ao carregar modelo"
        case (.connected, .unloaded, _):
            "Modelo não carregado"
        case (.connected, .loaded, .idle):
            "Pronto para transcrever"
        case (.connected, .loaded, .preparing):
            "Preparando áudio..."
        case (.connected, .loaded, .processing):
            self.formattedProgress
        case (.connected, .loaded, .postProcessing):
            "Processando resultado..."
        case (.connected, .loaded, .completed):
            "Transcrição concluída!"
        case (.connected, .loaded, .failed):
            self.lastError?.localizedDescription ?? "Falha na transcrição"
        default:
            "Status desconhecido"
        }
    }

    /// Returns formatted progress string.
    private var formattedProgress: String {
        if let estimated = estimatedTimeRemaining, estimated > 0 {
            return "Transcrevendo... \(Int(self.progressPercentage))% (~\(TimeFormatter.format(estimated)) restante)"
        } else if self.progressPercentage > 0 {
            return "Transcrevendo... \(Int(self.progressPercentage))%"
        }
        return "Transcrevendo áudio..."
    }

    /// Whether system is ready for transcription.
    public var isReady: Bool {
        self.serviceState == .connected && self.modelState == .loaded && self.phase == .idle
    }

    /// Whether transcription is currently in progress.
    public var isProcessing: Bool {
        [.preparing, .processing, .postProcessing].contains(self.phase)
    }

    /// Whether there's a blocking error.
    public var hasBlockingError: Bool {
        self.serviceState == .error || self.serviceState == .disconnected || self.modelState == .error
    }

    // MARK: - Update Methods

    /// Update service connection state.
    public func updateServiceState(_ state: ServiceState) {
        self.serviceState = state
        if state == .connected {
            self.lastHealthCheck = Date()
        }
    }

    /// Update model loading state.
    public func updateModelState(_ state: ModelState, device: String? = nil) {
        self.modelState = state
        if let device {
            self.device = device
        }
    }

    /// Begins a new transcription session.
    public func beginTranscription(audioDuration: Double?) {
        self.phase = .preparing
        self.progressPercentage = 0.0
        self.estimatedTimeRemaining = nil
        self.audioDurationSeconds = audioDuration
        self.processedDurationSeconds = 0.0
        self.transcriptionStartTime = Date()
        self.lastError = nil
    }

    /// Updates transcription progress during processing.
    public func updateProgress(
        phase: TranscriptionPhase,
        percentage: Double? = nil,
        processedSeconds: Double? = nil
    ) {
        self.phase = phase

        if let percentage {
            self.progressPercentage = min(max(percentage, 0.0), 100.0)
        }

        if let processed = processedSeconds {
            self.processedDurationSeconds = processed
            self.calculateEstimatedTime()
        }
    }

    /// Marks transcription as completed.
    public func completeTranscription(success: Bool) {
        self.phase = success ? .completed : .failed
        self.progressPercentage = success ? 100.0 : self.progressPercentage
        self.estimatedTimeRemaining = nil
        self.transcriptionStartTime = nil
    }

    /// Resets to idle state after completion.
    public func resetToIdle() {
        self.phase = .idle
        self.progressPercentage = 0.0
        self.estimatedTimeRemaining = nil
        self.audioDurationSeconds = nil
        self.processedDurationSeconds = 0.0
        self.transcriptionStartTime = nil
    }

    /// Records an error that occurred.
    public func recordError(_ error: TranscriptionStatusError) {
        self.lastError = error
        self.lastErrorTime = Date()

        // Update state based on error type
        switch error {
        case .serviceUnavailable, .connectionFailed:
            self.serviceState = .disconnected
        case .modelLoadFailed:
            self.modelState = .error
        case .transcriptionFailed:
            self.phase = .failed
        }
    }

    /// Clears error state.
    public func clearError() {
        self.lastError = nil
        self.lastErrorTime = nil
    }

    // MARK: - Private Methods

    /// Calculates estimated time remaining based on processing speed.
    private func calculateEstimatedTime() {
        guard let startTime = transcriptionStartTime,
              let audioDuration = audioDurationSeconds,
              processedDurationSeconds > 0
        else {
            self.estimatedTimeRemaining = nil
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let processingSpeed = self.processedDurationSeconds / elapsed

        guard processingSpeed > 0 else {
            self.estimatedTimeRemaining = nil
            return
        }

        let remainingAudio = audioDuration - self.processedDurationSeconds
        self.estimatedTimeRemaining = remainingAudio / processingSpeed

        // Update percentage based on processed duration
        self.progressPercentage = (self.processedDurationSeconds / audioDuration) * 100.0
    }
}

// MARK: - Error Types

/// Errors related to transcription status.
public enum TranscriptionStatusError: LocalizedError, Equatable {
    case serviceUnavailable
    case connectionFailed(String)
    case modelLoadFailed(String)
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            "Serviço de transcrição indisponível"
        case let .connectionFailed(reason):
            "Falha na conexão: \(reason)"
        case let .modelLoadFailed(reason):
            "Erro ao carregar modelo: \(reason)"
        case let .transcriptionFailed(reason):
            "Falha na transcrição: \(reason)"
        }
    }
}
