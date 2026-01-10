// Domain Protocols - Interfaces para infraestrutura seguindo Clean Architecture

import Foundation

// MARK: - Recording Domain Protocols

/// Protocolo para operações de gravação de áudio
public protocol RecordingRepository: Sendable {
    /// Inicia gravação para URL especificada
    func startRecording(to outputURL: URL, retryCount: Int) async throws

    /// Para gravação e retorna URL do arquivo criado
    func stopRecording() async throws -> URL?

    /// Verifica se permissão está concedida
    func hasPermission() async -> Bool

    /// Solicita permissão do usuário
    func requestPermission() async

    /// Obtém estado detalhado da permissão
    func getPermissionState() -> DomainPermissionState

    /// Abre configurações do sistema para esta permissão
    func openSettings() async
}

/// Protocolo para operações de arquivo de áudio
public protocol AudioFileRepository: Sendable {
    /// Salva arquivo de áudio
    func saveAudioFile(from sourceURL: URL, to destinationURL: URL) async throws

    /// Remove arquivo de áudio
    func deleteAudioFile(at url: URL) async throws

    /// Verifica se arquivo existe
    func audioFileExists(at url: URL) -> Bool

    /// Obtém URL para novo arquivo de áudio
    func generateAudioFileURL(for meetingId: UUID) -> URL

    /// Lista arquivos de áudio
    func listAudioFiles() async throws -> [URL]
}

// MARK: - Transcription Domain Protocols

/// Protocolo para operações de transcrição
public protocol TranscriptionRepository: Sendable {
    /// Verifica saúde do serviço
    func healthCheck() async throws -> Bool

    /// Busca status detalhado do serviço
    func fetchServiceStatus() async throws -> DomainServiceStatusResponse

    /// Transcreve arquivo de áudio
    func transcribe(audioURL: URL) async throws -> DomainTranscriptionResponse
}

/// Protocolo para operações de pós-processamento
public protocol PostProcessingRepository: Sendable {
    /// Processa texto de transcrição usando prompt selecionado
    func processTranscription(_ transcription: String) async throws -> String

    /// Processa texto de transcrição usando prompt específico
    func processTranscription(_ transcription: String, with prompt: DomainPostProcessingPrompt) async throws -> String
}

// MARK: - Storage Domain Protocols

/// Protocolo para operações de armazenamento de reuniões
public protocol MeetingRepository: Sendable {
    /// Salva reunião
    func saveMeeting(_ meeting: MeetingEntity) async throws

    /// Busca reunião por ID
    func fetchMeeting(by id: UUID) async throws -> MeetingEntity?

    /// Lista todas as reuniões
    func fetchAllMeetings() async throws -> [MeetingEntity]

    /// Remove reunião
    func deleteMeeting(by id: UUID) async throws

    /// Atualiza reunião
    func updateMeeting(_ meeting: MeetingEntity) async throws
}

/// Protocolo para operações de armazenamento de transcrições
public protocol TranscriptionStorageRepository: Sendable {
    /// Salva transcrição
    func saveTranscription(_ transcription: TranscriptionEntity) async throws

    /// Busca transcrição por ID
    func fetchTranscription(by id: UUID) async throws -> TranscriptionEntity?

    /// Lista transcrições para reunião
    func fetchTranscriptions(for meetingId: UUID) async throws -> [TranscriptionEntity]

    /// Lista todas as transcrições
    func fetchAllTranscriptions() async throws -> [TranscriptionEntity]

    /// Remove transcrição
    func deleteTranscription(by id: UUID) async throws

    /// Atualiza transcrição
    func updateTranscription(_ transcription: TranscriptionEntity) async throws
}

// MARK: - Supporting Types

/// Estados de permissão do domínio
public enum DomainPermissionState: Sendable {
    case granted
    case denied
    case notDetermined
    case restricted
}

/// Resposta de status do serviço do domínio
public struct DomainServiceStatusResponse: Codable, Sendable {
    public let status: String
    public let message: String
    public let timestamp: Date

    public init(status: String, message: String, timestamp: Date = Date()) {
        self.status = status
        self.message = message
        self.timestamp = timestamp
    }
}

/// Erro de pós-processamento do domínio
public enum DomainPostProcessingError: Error, Sendable {
    case serviceUnavailable
    case invalidPrompt
    case processingFailed(String)
    case networkError(Error)
}

/// Prompt de pós-processamento do domínio
public struct DomainPostProcessingPrompt: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let content: String
    public let isDefault: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

/// Resposta de transcrição do domínio
public struct DomainTranscriptionResponse: Codable, Sendable {
    public let text: String
    public let language: String
    public let durationSeconds: Double
    public let model: String
    public let processedAt: String
    public let segments: [DomainTranscriptionSegment]

    public init(
        text: String,
        segments: [DomainTranscriptionSegment] = [],
        language: String,
        durationSeconds: Double,
        model: String,
        processedAt: String
    ) {
        self.text = text
        self.language = language
        self.durationSeconds = durationSeconds
        self.model = model
        self.processedAt = processedAt
        self.segments = segments
    }
}

/// Segmento de transcrição do domínio
public struct DomainTranscriptionSegment: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let speaker: String
    public let text: String
    public let startTime: Double
    public let endTime: Double

    public init(
        id: UUID = UUID(),
        speaker: String,
        text: String,
        startTime: Double,
        endTime: Double
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}