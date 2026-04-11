import Foundation

public extension AppSettingsStore {
    func updateTranscriptionDictationProvider(_ provider: TranscriptionProvider) {
        let selectedModel = transcriptionSelectedModel(for: provider)
        transcriptionDictationSelection = TranscriptionProviderSelection(
            provider: provider,
            selectedModel: selectedModel
        )
        setTranscriptionProviderSelectedModel(selectedModel, for: provider)
    }

    func updateTranscriptionDictationModel(_ model: String) {
        let provider = transcriptionDictationSelection.provider
        let normalizedModel = normalizedTranscriptionModelID(model, for: provider)
        transcriptionDictationSelection = TranscriptionProviderSelection(
            provider: provider,
            selectedModel: normalizedModel
        )
        setTranscriptionProviderSelectedModel(normalizedModel, for: provider)
    }

    func updateTranscriptionDictationSelection(
        provider: TranscriptionProvider,
        model: String
    ) {
        let normalizedModel = normalizedTranscriptionModelID(model, for: provider)
        transcriptionDictationSelection = TranscriptionProviderSelection(
            provider: provider,
            selectedModel: normalizedModel
        )
        setTranscriptionProviderSelectedModel(normalizedModel, for: provider)
    }

    func transcriptionSelectedModel(for provider: TranscriptionProvider) -> String {
        let cachedModel = transcriptionProviderSelectedModels[provider.rawValue] ?? ""
        if !cachedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalizedTranscriptionModelID(cachedModel, for: provider)
        }

        if transcriptionDictationSelection.provider == provider {
            return normalizedTranscriptionModelID(transcriptionDictationSelection.selectedModel, for: provider)
        }

        return provider.defaultModelID
    }

    func normalizedTranscriptionModelID(_ model: String, for provider: TranscriptionProvider) -> String {
        provider.normalizedModelID(model)
    }

    func resolvedTranscriptionSelection(for mode: TranscriptionExecutionMode) -> TranscriptionProviderSelection {
        switch mode {
        case .meeting:
            return TranscriptionProviderSelection(
                provider: .local,
                selectedModel: TranscriptionProvider.localModelID
            )
        case .dictation, .assistant:
            let provider = transcriptionDictationSelection.provider
            return TranscriptionProviderSelection(
                provider: provider,
                selectedModel: transcriptionSelectedModel(for: provider)
            )
        }
    }

    func shouldUseRemoteTranscription(for mode: TranscriptionExecutionMode) -> Bool {
        resolvedTranscriptionSelection(for: mode).provider.usesRemoteInference
    }

    func supportsIncrementalTranscription(for mode: TranscriptionExecutionMode) -> Bool {
        !shouldUseRemoteTranscription(for: mode)
    }

    func setTranscriptionProviderSelectedModel(_ model: String, for provider: TranscriptionProvider) {
        let normalizedModel = normalizedTranscriptionModelID(model, for: provider)
        var updated = transcriptionProviderSelectedModels
        updated[provider.rawValue] = normalizedModel
        transcriptionProviderSelectedModels = updated
    }
}
