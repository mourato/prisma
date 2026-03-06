import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

#Preview("Conversation") {
    MeetingConversationView(
        transcription: .previewConversation,
        isLoadingTranscription: false,
        turns: [
            .init(
                question: "What did we decide about previews?",
                response: MeetingQAResponse(
                    status: .answered,
                    answer: "The team decided to prioritize screens with startup side effects.",
                    evidence: [
                        .init(
                            speaker: "Speaker 2",
                            startTime: 10,
                            endTime: 21,
                            excerpt: "Vou priorizar as telas com side effects na fase seguinte."
                        ),
                    ]
                ),
                errorMessage: nil
            ),
        ],
        questionText: "",
        onQuestionChange: { _ in },
        onAsk: {},
        onRetry: { _ in },
        isAnswering: false,
        currentErrorMessage: nil,
        effectiveModelSelection: MeetingQAModelSelection(
            providerRawValue: AIProvider.openai.rawValue,
            modelID: "gpt-4o"
        ),
        modelOptions: [
            .init(provider: .openai, modelID: "gpt-4o"),
            .init(provider: .openai, modelID: "gpt-4.1-mini"),
        ],
        isLoadingModelOptions: false,
        onModelChange: { _ in },
        onRefreshModelOptions: {},
        dictationState: .idle,
        dictationErrorMessage: nil,
        onToggleDictation: {},
        onBack: {}
    )
    .frame(width: 700, height: 700)
}

#Preview("Dictation Recording") {
    MeetingConversationView(
        transcription: .previewConversation,
        isLoadingTranscription: false,
        turns: [],
        questionText: "",
        onQuestionChange: { _ in },
        onAsk: {},
        onRetry: { _ in },
        isAnswering: false,
        currentErrorMessage: nil,
        effectiveModelSelection: MeetingQAModelSelection(
            providerRawValue: AIProvider.openai.rawValue,
            modelID: "gpt-4o"
        ),
        modelOptions: [.init(provider: .openai, modelID: "gpt-4o")],
        isLoadingModelOptions: false,
        onModelChange: { _ in },
        onRefreshModelOptions: {},
        dictationState: .recording,
        dictationErrorMessage: nil,
        onToggleDictation: {},
        onBack: {}
    )
    .frame(width: 700, height: 700)
}

private extension Transcription {
    static var previewConversation: Transcription {
        Transcription(
            meeting: Meeting(
                app: .slack,
                state: .completed,
                startTime: Date().addingTimeInterval(-1_800),
                endTime: Date().addingTimeInterval(-600),
                audioFilePath: nil
            ),
            segments: [
                .init(speaker: "Speaker 1", text: "Precisamos consolidar os previews da interface.", startTime: 0, endTime: 9),
                .init(speaker: "Speaker 2", text: "Vou priorizar as telas com side effects na fase seguinte.", startTime: 10, endTime: 21),
            ],
            text: "Precisamos consolidar os previews da interface. Vou priorizar as telas com side effects na fase seguinte.",
            rawText: "precisamos consolidar previews interface vou priorizar telas com side effects na fase seguinte",
            processedContent: "Precisamos consolidar os previews da interface e priorizar, na sequencia, as telas com side effects.",
            postProcessingPromptTitle: "Planning summary",
            language: "pt"
        )
    }
}
