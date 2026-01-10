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

        private static let fallbackMeetingNotes = UUID(
            uuidString: "00000000-0000-0000-0000-000000000001"
        )!
        private static let fallbackExecutiveSummary = UUID(
            uuidString: "00000000-0000-0000-0000-000000000002"
        )!
        private static let fallbackActionItems = UUID(
            uuidString: "00000000-0000-0000-0000-000000000003"
        )!
        private static let fallbackCleanTranscription = UUID(
            uuidString: "00000000-0000-0000-0000-000000000004"
        )!

        static let meetingNotes: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001") else {
                assertionFailure("Invalid UUID string for meetingNotes")
                return fallbackMeetingNotes
            }
            return uuid
        }()

        static let executiveSummary: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000002") else {
                assertionFailure("Invalid UUID string for executiveSummary")
                return fallbackExecutiveSummary
            }
            return uuid
        }()

        static let actionItems: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000003") else {
                assertionFailure("Invalid UUID string for actionItems")
                return fallbackActionItems
            }
            return uuid
        }()

        static let cleanTranscription: UUID = {
            guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000004") else {
                assertionFailure("Invalid UUID string for cleanTranscription")
                return fallbackCleanTranscription
            }
            return uuid
        }()
    }

    /// Predefined prompt for generating meeting notes.
    static let meetingNotes = PostProcessingPrompt(
        id: PredefinedIDs.meetingNotes,
        title: "Notas de Reunião",
        promptText: """
        Analise a transcrição e gere notas de reunião estruturadas com:
        - Participantes mencionados
        - Tópicos principais discutidos
        - Decisões tomadas
        - Pontos de atenção

        Mantenha um formato limpo e profissional.
        """,
        icon: "note.text",
        description: "Gera notas de reunião estruturadas",
        isPredefined: true
    )

    /// Predefined prompt for executive summary.
    static let executiveSummary = PostProcessingPrompt(
        id: PredefinedIDs.executiveSummary,
        title: "Resumo Executivo",
        promptText: """
        Crie um resumo executivo conciso da reunião em 3-5 parágrafos.
        Foque nos pontos mais importantes e nas conclusões principais.
        Use linguagem clara e objetiva, apropriada para stakeholders.
        """,
        icon: "doc.text.magnifyingglass",
        description: "Cria um resumo executivo conciso",
        isPredefined: true
    )

    /// Predefined prompt for extracting action items.
    static let actionItems = PostProcessingPrompt(
        id: PredefinedIDs.actionItems,
        title: "Action Items",
        promptText: """
        Extraia todos os action items e próximos passos mencionados na reunião.
        Para cada item, identifique (quando disponível):
        - Responsável
        - Prazo mencionado
        - Contexto/detalhes relevantes

        Liste em formato de checklist.
        """,
        icon: "checklist",
        description: "Extrai tarefas e próximos passos",
        isPredefined: true
    )

    /// Predefined prompt for clean transcription.
    static let cleanTranscription = PostProcessingPrompt(
        id: PredefinedIDs.cleanTranscription,
        title: "Transcrição Limpa",
        promptText: """
        Limpe a transcrição removendo:
        - Hesitações e palavras de preenchimento (uh, uhm, é...)
        - Repetições desnecessárias
        - Correções de erros de fala

        Mantenha o conteúdo original, apenas melhorando a legibilidade.
        Não altere o significado ou adicione informações.
        """,
        icon: "text.badge.checkmark",
        description: "Remove hesitações e corrige erros de fala",
        isPredefined: true
    )

    /// All predefined prompts.
    static let allPredefined: [PostProcessingPrompt] = [
        .meetingNotes,
        .executiveSummary,
        .actionItems,
        .cleanTranscription,
    ]
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
