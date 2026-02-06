import Foundation

// MARK: - Post-Processing Prompt Model

/// Represents a customizable prompt for post-processing transcriptions.
/// Prompts can be predefined (read-only) or user-created (editable).
public struct PostProcessingPrompt: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var promptText: String
    public var isActive: Bool
    public var icon: String
    public var description: String?
    public let isPredefined: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        promptText: String,
        isActive: Bool = false,
        icon: String = "doc.text.fill",
        description: String? = nil,
        isPredefined: Bool = false
    ) {
        self.id = id
        self.title = title
        self.promptText = promptText
        self.isActive = isActive
        self.icon = icon
        self.description = description
        self.isPredefined = isPredefined
    }
}

// MARK: - Predefined Prompts

public extension PostProcessingPrompt {
    /// Stable UUIDs for predefined prompts to ensure persistence consistency.
    private enum PredefinedIDs {
        // MARK: - Fallback UUIDs (valid for all Swift versions)

        private static func uuid(_ string: String) -> UUID {
            UUID(uuidString: string) ?? UUID()
        }

        private static let fallbackCleanTranscription = uuid("00000000-0000-0000-0000-000000000004")
        private static let fallbackStandup = uuid("00000000-0000-0000-0000-000000000005")
        private static let fallbackPresentation = uuid("00000000-0000-0000-0000-000000000006")
        private static let fallbackDesignReview = uuid("00000000-0000-0000-0000-000000000007")
        private static let fallbackOneOnOne = uuid("00000000-0000-0000-0000-000000000008")
        private static let fallbackPlanning = uuid("00000000-0000-0000-0000-000000000009")

        static let cleanTranscription: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000004") else {
                assertionFailure("Invalid UUID string for cleanTranscription")
                return fallbackCleanTranscription
            }
            return uuid
        }()

        static let standup: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000005") else {
                assertionFailure("Invalid UUID string for standup")
                return fallbackStandup
            }
            return uuid
        }()

        static let presentation: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000006") else {
                assertionFailure("Invalid UUID string for presentation")
                return fallbackPresentation
            }
            return uuid
        }()

        static let designReview: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000007") else {
                assertionFailure("Invalid UUID string for designReview")
                return fallbackDesignReview
            }
            return uuid
        }()

        static let oneOnOne: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000008") else {
                assertionFailure("Invalid UUID string for oneOnOne")
                return fallbackOneOnOne
            }
            return uuid
        }()

        static let planning: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000009") else {
                assertionFailure("Invalid UUID string for planning")
                return fallbackPlanning
            }
            return uuid
        }()
    }

    /// Predefined prompt for clean transcription.
    static let cleanTranscription = PostProcessingPrompt(
        id: PredefinedIDs.cleanTranscription,
        title: "prompt.clean_transcription.title".localized,
        promptText: """
        Limpe a transcrição removendo:
        - Hesitações e palavras de preenchimento (uh, uhm, é...)
        - Repetições desnecessárias
        - Correções de erros de fala

        Mantenha o conteúdo original, apenas melhorando a legibilidade.
        Não altere o significado ou adicione informações.
        """,
        icon: "text.badge.checkmark",
        description: "prompt.clean_transcription.description".localized,
        isPredefined: true
    )

    /// All predefined prompts.
    static let allPredefined: [PostProcessingPrompt] = [
        .cleanTranscription,
        .standup,
        .presentation,
        .designReview,
        .oneOnOne,
        .planning,
    ]
}

// MARK: - New Meeting Prompts

public extension PostProcessingPrompt {
    /// Predefined prompt for Standup meetings.
    static let standup = PostProcessingPrompt(
        id: PredefinedIDs.standup,
        title: "prompt.standup.title".localized,
        promptText: """
        Analise a transcrição deste Standup e identifique:
        - O que foi feito (Progresso)
        - O que será feito (Planejamento)
        - Impedimentos/Bloqueios
        
        Ignore conversas paralelas e foque atualizações objetivas.
        """,
        icon: "figure.stand",
        description: "prompt.standup.description".localized,
        isPredefined: true
    )

    /// Predefined prompt for Presentations.
    static let presentation = PostProcessingPrompt(
        id: PredefinedIDs.presentation,
        title: "prompt.presentation.title".localized,
        promptText: """
        Resuma esta apresentação focando na mensagem principal.
        - Destaque os key takeaways
        - Resuma o conteúdo dos slides/tópicos apresentados
        - Ignore interações irrelevantes da plateia, a menos que sejam perguntas pertinentes (Q&A).
        """,
        icon: "tv",
        description: "prompt.presentation.description".localized,
        isPredefined: true
    )

    /// Predefined prompt for Design Reviews.
    static let designReview = PostProcessingPrompt(
        id: PredefinedIDs.designReview,
        title: "prompt.design_review.title".localized,
        promptText: """
        Sintetize esta revisão de design:
        - Liste os feedbacks fornecidos (positivos e pontos de melhoria)
        - Explicite as decisões de design tomadas
        - Identifique questões em aberto sobre UX/UI
        """,
        icon: "paintbrush",
        description: "prompt.design_review.description".localized,
        isPredefined: true
    )

    /// Predefined prompt for One-on-Ones.
    static let oneOnOne = PostProcessingPrompt(
        id: PredefinedIDs.oneOnOne,
        title: "prompt.one_on_one.title".localized,
        promptText: """
        Resuma este 1:1 com foco em:
        - Acordos firmados
        - Discussões sobre carreira/crescimento (se houver)
        - Action items para ambas as partes
        
        Mantenha a discrição e profissionalismo, focando em outcomes.
        """,
        icon: "person.2",
        description: "prompt.one_on_one.description".localized,
        isPredefined: true
    )

    /// Predefined prompt for Planning meetings.
    static let planning = PostProcessingPrompt(
        id: PredefinedIDs.planning,
        title: "prompt.planning.title".localized,
        promptText: """
        Resuma esta reunião de planejamento:
        - Definições de escopo (o que entra, o que sai)
        - Prazos e cronogramas definidos
        - Atribuição de responsabilidades (quem faz o quê)
        - Objetivos da sprint/projeto
        """,
        icon: "map",
        description: "prompt.planning.description".localized,
        isPredefined: true
    )

    /// Internal prompt for classifying meeting type.
    static let classifier = PostProcessingPrompt(
        id: UUID(), // Internal, doesn't need stable ID
        title: "Classifier",
        promptText: """
        Analise a transcrição e classifique o tipo de reunião.
        Responda APENAS com o JSON no seguinte formato:
        {
            "type": "ONE_OF_THE_VALUES"
        }
        
        Valores possíveis:
        - standup
        - presentation
        - design_review
        - one_on_one
        - planning
        - general
        
        Não forneça explicação, apenas o JSON.
        """,
        isActive: true,
        icon: "tag",
        isPredefined: true
    )

}

// MARK: - Icon Options

public extension PostProcessingPrompt {
    /// Available SF Symbol icons for prompts.
    static let availableIcons: [String] = [
        // Document & Text
        "doc.text.fill",
        "doc.text.magnifyingglass",
        "note.text",
        "text.badge.checkmark",

        // Organization
        "checklist",
        "list.bullet",
        "list.bullet.rectangle",
        "folder.fill",

        // Communication
        "bubble.left.and.bubble.right.fill",
        "message.fill",
        "envelope.fill",

        // Professional
        "person.2.fill",
        "briefcase.fill",
        "building.2.fill",

        // Technical
        "terminal.fill",
        "gearshape.fill",
        "wrench.and.screwdriver.fill",

        // Content
        "book.fill",
        "bookmark.fill",
        "pencil.circle.fill",

        // Productivity
        "clock.fill",
        "calendar",
        "chart.bar.fill",
        "target",
        "lightbulb.fill",
        "star.fill",
        "flag.fill",
    ]
}
