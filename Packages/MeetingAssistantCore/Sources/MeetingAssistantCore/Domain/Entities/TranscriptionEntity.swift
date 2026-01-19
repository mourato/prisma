// TranscriptionEntity - Domain Entity pura sem dependências de UI/frameworks

import Foundation

/// Representa uma transcrição completada.
public struct TranscriptionEntity: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let meeting: MeetingEntity

    /// Segmentos da transcrição com identificação de speaker.
    public let segments: [Segment]

    /// Texto primário para exibição (processado se disponível, caso contrário raw).
    public let text: String

    /// Transcrição original do modelo ASR.
    public let rawText: String

    /// Conteúdo processado de pós-processamento AI (nil se não processado).
    public var processedContent: String?

    /// ID do prompt usado para pós-processamento (nil se não processado).
    public var postProcessingPromptId: UUID?

    /// Título do prompt usado para pós-processamento (nil se não processado).
    public var postProcessingPromptTitle: String?

    public let language: String
    public let createdAt: Date
    public let modelName: String

    /// Inicializador completo com suporte a pós-processamento.
    public init(
        id: UUID = UUID(),
        meeting: MeetingEntity,
        segments: [Segment] = [],
        text: String,
        rawText: String,
        processedContent: String? = nil,
        postProcessingPromptId: UUID? = nil,
        postProcessingPromptTitle: String? = nil,
        language: String = "pt",
        createdAt: Date = Date(),
        modelName: String = "parakeet-tdt-0.6b-v3"
    ) {
        self.id = id
        self.meeting = meeting
        self.segments = segments
        self.text = text
        self.rawText = rawText
        self.processedContent = processedContent
        self.postProcessingPromptId = postProcessingPromptId
        self.postProcessingPromptTitle = postProcessingPromptTitle
        self.language = language
        self.createdAt = createdAt
        self.modelName = modelName
    }

    /// Inicializador de conveniência para compatibilidade retroativa (sem pós-processamento).
    public init(
        id: UUID = UUID(),
        meeting: MeetingEntity,
        text: String,
        language: String = "pt",
        createdAt: Date = Date(),
        modelName: String = "parakeet-tdt-0.6b-v3"
    ) {
        self.init(
            id: id,
            meeting: meeting,
            segments: [],
            text: text,
            rawText: text,
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: language,
            createdAt: createdAt,
            modelName: modelName
        )
    }

    /// Se esta transcrição foi pós-processada.
    public var isPostProcessed: Bool {
        processedContent != nil
    }

    /// Contagem de palavras da transcrição.
    public var wordCount: Int {
        text.split(separator: " ").count
    }

    /// Prévia do texto da transcrição (primeiros 100 chars).
    public var preview: String {
        if text.count <= 100 {
            return text
        }
        return String(text.prefix(100)) + "..."
    }

    /// Prévia curta para lista de exibição (primeiros 80 chars).
    public var truncatedPreview: String {
        if text.count <= 80 {
            return text
        }
        return String(text.prefix(80)) + "..."
    }

    /// Um segmento da transcrição associado a um speaker.
    public struct Segment: Identifiable, Codable, Hashable, Sendable {
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

    /// String padrão para speaker desconhecido.
    public static let unknownSpeaker = "Desconhecido"
}
