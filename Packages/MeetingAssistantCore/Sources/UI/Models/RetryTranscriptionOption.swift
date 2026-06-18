import MeetingAssistantCoreInfrastructure

public struct RetryTranscriptionOption: Identifiable, Sendable {
    public let selection: TranscriptionProviderSelection

    public init(selection: TranscriptionProviderSelection) {
        self.selection = selection
    }

    public var id: String {
        "\(selection.provider.rawValue)::\(selection.selectedModel)"
    }

    public var displayName: String {
        let providerName = selection.provider.displayName
        let modelName = selection.provider.displayName(forModelID: selection.selectedModel)
        return "\(providerName) - \(modelName)"
    }
}
