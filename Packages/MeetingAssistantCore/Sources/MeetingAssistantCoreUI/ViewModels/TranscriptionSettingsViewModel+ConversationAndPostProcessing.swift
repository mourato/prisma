import AppKit
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import OSLog
import SwiftUI

public extension TranscriptionSettingsViewModel {
    enum ManualTranscriptionExportKind: Sendable {
        case summary
        case original

        var filenameSuffixKey: String? {
            switch self {
            case .summary:
                nil
            case .original:
                "transcription.export.filename.original_suffix"
            }
        }

        var emptyContentErrorKey: String {
            switch self {
            case .summary:
                "transcription.export.error.empty_summary"
            case .original:
                "transcription.export.error.empty_original"
            }
        }
    }

    static func manualExportSuggestedFilename(
        baseFilename: String,
        kind: ManualTranscriptionExportKind
    ) -> String {
        guard let suffixKey = kind.filenameSuffixKey else {
            return "\(baseFilename).md"
        }

        return "\(baseFilename) \(suffixKey.localized).md"
    }

    func submitQuestion(for transcription: Transcription) async {
        let trimmedQuestion = qaQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            qaErrorMessage = "transcription.qa.error.empty_question".localized
            return
        }

        await askQuestion(trimmedQuestion, for: transcription)
    }

    func retryLastQuestion(for transcription: Transcription) async {
        guard let lastAskedQuestion,
              lastQuestionTranscriptionId == transcription.id
        else {
            qaErrorMessage = "transcription.qa.error.no_retry_context".localized
            return
        }

        qaQuestion = lastAskedQuestion
        await askQuestion(lastAskedQuestion, for: transcription)
    }

    func retryQuestion(_ question: String, for transcription: Transcription) async {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            qaErrorMessage = "transcription.qa.error.empty_question".localized
            return
        }

        qaQuestion = trimmedQuestion
        await askQuestion(trimmedQuestion, for: transcription)
    }

    private func askQuestion(_ question: String, for transcription: Transcription) async {
        guard transcription.supportsMeetingConversation else {
            qaErrorMessage = localizedQuestionError(for: .disabled)
            return
        }

        guard !isAnsweringQuestion else { return }

        isAnsweringQuestion = true
        qaErrorMessage = nil
        lastAskedQuestion = question
        lastQuestionTranscriptionId = transcription.id
        defer { isAnsweringQuestion = false }

        do {
            let request = IntelligenceKernelQuestionRequest(
                mode: .meeting,
                question: question,
                transcription: transcription,
                modelSelectionOverride: qaModelSelectionByTranscription[transcription.id]
            )
            let response = try await meetingQAService.ask(request)
            qaResponse = response
            appendQATurn(
                QATurn(
                    question: question,
                    response: response,
                    errorMessage: nil
                ),
                transcriptionID: transcription.id
            )
            await persistMeetingConversationState(for: transcription.id)
        } catch let error as MeetingQAError {
            qaErrorMessage = localizedQuestionError(for: error)
            appendQATurn(
                QATurn(
                    question: question,
                    response: nil,
                    errorMessage: qaErrorMessage
                ),
                transcriptionID: transcription.id
            )
            await persistMeetingConversationState(for: transcription.id)
        } catch {
            qaErrorMessage = "transcription.qa.error.generic".localized
            appendQATurn(
                QATurn(
                    question: question,
                    response: nil,
                    errorMessage: qaErrorMessage
                ),
                transcriptionID: transcription.id
            )
            await persistMeetingConversationState(for: transcription.id)
        }
    }

    private func localizedQuestionError(for error: MeetingQAError) -> String {
        switch error {
        case .disabled:
            "transcription.qa.error.disabled".localized
        case .emptyQuestion:
            "transcription.qa.error.empty_question".localized
        case .noAPIConfigured:
            "transcription.qa.error.no_api".localized
        case .invalidURL:
            "transcription.qa.error.invalid_url".localized
        case .timeout:
            "transcription.qa.error.timeout".localized
        case .networkUnavailable:
            "transcription.qa.error.network".localized
        case .invalidResponse:
            "transcription.qa.error.invalid_response".localized
        case .requestFailed:
            "transcription.qa.error.generic".localized
        }
    }

    func resetQuestionState() {
        qaQuestion = ""
        qaResponse = nil
        qaErrorMessage = nil
        lastAskedQuestion = nil
        lastQuestionTranscriptionId = nil
    }

    func clearQuestionComposer() {
        qaQuestion = ""
        qaErrorMessage = nil
    }

    private func appendQATurn(_ turn: QATurn, transcriptionID: UUID) {
        var turns = qaHistoryByTranscription[transcriptionID] ?? []
        turns.append(turn)
        qaHistoryByTranscription[transcriptionID] = turns
    }

    func isPostProcessing(transcriptionID: UUID) -> Bool {
        postProcessingByTranscriptionID.contains(transcriptionID)
    }

    func postProcessingError(for transcriptionID: UUID) -> String? {
        postProcessingErrorByTranscriptionID[transcriptionID]
    }

    var availablePrompts: [PostProcessingPrompt] {
        AppSettingsStore.shared.allPrompts
    }

    func availablePrompts(for metadata: TranscriptionMetadata) -> [PostProcessingPrompt] {
        if !metadata.supportsMeetingConversation {
            return AppSettingsStore.shared.dictationAvailablePrompts
        }
        return AppSettingsStore.shared.meetingAvailablePrompts
    }

    func applyPostProcessing(prompt: PostProcessingPrompt, to transcription: Transcription) async {
        guard !isProcessingAI else { return }

        let transcriptionID = transcription.id
        markPostProcessingStarted(for: transcriptionID)
        let startTime = Date()
        defer { markPostProcessingFinished(for: transcriptionID) }

        do {
            let postProcessingInput = postProcessingInput(for: transcription)
            let processedText = try await PostProcessingService.shared.processTranscription(
                postProcessingInput,
                with: prompt
            )

            let duration = Date().timeIntervalSince(startTime)
            let config = AppSettingsStore.shared.resolvedEnhancementsAIConfiguration
            let modelUsed = config.selectedModel

            let sortedSegments = sortedSegments(transcription.segments)
            let updatedTranscription = Transcription(
                id: transcription.id,
                meeting: transcription.meeting,
                contextItems: transcription.contextItems,
                segments: sortedSegments,
                text: transcription.text,
                rawText: transcription.rawText,
                processedContent: processedText,
                canonicalSummary: transcription.canonicalSummary,
                qualityProfile: transcription.qualityProfile,
                postProcessingPromptId: prompt.id,
                postProcessingPromptTitle: prompt.title,
                language: transcription.language,
                createdAt: transcription.createdAt,
                modelName: transcription.modelName,
                inputSource: transcription.inputSource,
                transcriptionDuration: transcription.transcriptionDuration,
                postProcessingDuration: duration,
                postProcessingModel: modelUsed,
                meetingType: transcription.meetingType,
                meetingConversationState: transcription.meetingConversationState
            )

            try await storage.saveTranscription(updatedTranscription)

            // Update local state
            selectedTranscription = updatedTranscription
            clearPostProcessingError(for: transcriptionID)

            // Refresh metadata to show the "sparkles" icon in the list if needed
            await loadTranscriptions()

        } catch {
            logger.error("Failed to apply post-processing: \(error.localizedDescription)")
            let message = "transcription.post_processing.error".localized
            postProcessingErrorByTranscriptionID[transcriptionID] = message
            operationErrorMessage = message
        }
    }

    func renameSpeaker(
        from originalSpeaker: String,
        to updatedSpeaker: String,
        in transcriptionID: UUID
    ) async {
        let oldValue = originalSpeaker.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = updatedSpeaker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldValue.isEmpty, !newValue.isEmpty, oldValue != newValue else { return }

        do {
            guard var transcription = selectedTranscription, transcription.id == transcriptionID else {
                guard var loaded = try await storage.loadTranscription(by: transcriptionID) else { return }
                try await renameSpeaker(in: &loaded, from: oldValue, to: newValue, selectedID: transcriptionID)
                return
            }

            try await renameSpeaker(in: &transcription, from: oldValue, to: newValue, selectedID: transcriptionID)
        } catch {
            logger.error("Failed to rename speaker: \(error.localizedDescription)")
            operationErrorMessage = "transcription.speaker.rename.error".localized
        }
    }

    func confirmDeleteTranscription(_ metadata: TranscriptionMetadata) {
        pendingDeleteTranscription = metadata
        showDeleteConfirmation = true
    }

    func cancelDeleteTranscription() {
        pendingDeleteTranscription = nil
        showDeleteConfirmation = false
    }

    func executeDeleteTranscription() async {
        guard let metadata = pendingDeleteTranscription else { return }
        await doDeleteTranscription(metadata)
        cancelDeleteTranscription()
    }

    private func doDeleteTranscription(_ metadata: TranscriptionMetadata) async {
        do {
            try await storage.deleteTranscription(by: metadata.id)
            if selectedId == metadata.id {
                selectedId = nil
            }
            await loadTranscriptions()
        } catch {
            logger.error("Failed to delete transcription: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    func exportTranscription(
        for metadata: TranscriptionMetadata,
        kind: ManualTranscriptionExportKind
    ) async {
        operationErrorMessage = nil
        do {
            guard let transcription = try await transcriptionForAction(metadata) else {
                operationErrorMessage = "transcription.export.error.missing_transcription".localized
                return
            }

            let exportContent = contentForManualExport(transcription: transcription, kind: kind)
            guard !exportContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                operationErrorMessage = kind.emptyContentErrorKey.localized
                return
            }

            let panel = savePanelProvider()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = suggestedExportFilename(for: transcription, kind: kind)

            let response = panel.runModal()
            guard response == .OK, let destinationURL = panel.url else {
                return
            }

            try summaryExportHelper.exportContentManually(exportContent, to: destinationURL)
        } catch {
            logger.error("Failed to manually export transcription: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    func retryTranscription(for metadata: TranscriptionMetadata) async {
        guard !recordingManager.isTranscribing else {
            return
        }

        do {
            guard let transcription = try await transcriptionForAction(metadata) else {
                operationErrorMessage = "transcription.retry.missing_transcription".localized
                return
            }

            guard let audioURL = transcription.audioURL else {
                operationErrorMessage = "transcription.retry.missing_audio".localized
                return
            }

            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                operationErrorMessage = "transcription.retry.missing_audio".localized
                return
            }

            await recordingManager.retryTranscription(for: transcription)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to retry transcription: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    func updateMeetingTitle(for metadata: TranscriptionMetadata, to title: String?) async {
        guard metadata.supportsMeetingConversation else { return }

        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle : nil

        do {
            let existing = try await meetingRepository.fetchMeeting(by: metadata.meetingId)
            let updatedMeeting = makeUpdatedMeetingEntity(
                existing: existing,
                metadata: metadata,
                app: existing?.app ?? (DomainMeetingApp(rawValue: metadata.appRawValue) ?? .unknown),
                title: normalizedTitle
            )

            try await meetingRepository.updateMeeting(updatedMeeting)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to update meeting title: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    func updateSource(for metadata: TranscriptionMetadata, isMeeting: Bool) async {
        let app = MeetingApp(rawValue: metadata.appRawValue) ?? .unknown
        guard app != .importedFile else { return }
        guard app == .unknown || app == .manualMeeting else { return }

        let targetApp: DomainMeetingApp = isMeeting ? .manualMeeting : .unknown

        do {
            let existing = try await meetingRepository.fetchMeeting(by: metadata.meetingId)
            let endTime = metadata.duration > 0
                ? metadata.startTime.addingTimeInterval(metadata.duration)
                : nil

            let updatedMeeting = makeUpdatedMeetingEntity(
                existing: existing,
                metadata: metadata,
                app: targetApp,
                title: existing?.title,
                fallbackEndTime: endTime
            )

            try await meetingRepository.updateMeeting(updatedMeeting)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to update recording source: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    private func transcriptionForAction(_ metadata: TranscriptionMetadata) async throws -> Transcription? {
        if selectedId == metadata.id, let current = selectedTranscription {
            return current
        }

        return try await storage.loadTranscription(by: metadata.id)
    }

    private func contentForManualExport(
        transcription: Transcription,
        kind: ManualTranscriptionExportKind
    ) -> String {
        switch kind {
        case .summary:
            transcription.processedContent ?? transcription.text
        case .original:
            transcription.rawText
        }
    }

    private func suggestedExportFilename(
        for transcription: Transcription,
        kind: ManualTranscriptionExportKind
    ) -> String {
        let baseFilename = summaryExportHelper.defaultExportFilename(for: transcription)
        return Self.manualExportSuggestedFilename(baseFilename: baseFilename, kind: kind)
    }

    private func makeUpdatedMeetingEntity(
        existing: MeetingEntity?,
        metadata: TranscriptionMetadata,
        app: DomainMeetingApp,
        title: String?,
        fallbackEndTime: Date? = nil
    ) -> MeetingEntity {
        MeetingEntity(
            id: metadata.meetingId,
            app: app,
            appBundleIdentifier: existing?.appBundleIdentifier ?? metadata.appBundleIdentifier,
            appDisplayName: existing?.appDisplayName ?? metadata.appName,
            title: title,
            linkedCalendarEvent: existing?.linkedCalendarEvent,
            startTime: existing?.startTime ?? metadata.startTime,
            endTime: existing?.endTime ?? fallbackEndTime,
            audioFilePath: existing?.audioFilePath ?? metadata.audioFilePath
        )
    }

    private func renameSpeaker(
        in transcription: inout Transcription,
        from oldValue: String,
        to newValue: String,
        selectedID: UUID
    ) async throws {
        let renamedSegments = transcription.segments.map { segment in
            guard segment.speaker == oldValue else { return segment }
            return Transcription.Segment(
                id: segment.id,
                speaker: newValue,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        guard renamedSegments != transcription.segments else { return }
        let sortedRenamedSegments = sortedSegments(renamedSegments)
        let updatedTranscription = Transcription(
            id: transcription.id,
            meeting: transcription.meeting,
            contextItems: transcription.contextItems,
            segments: sortedRenamedSegments,
            text: transcription.text,
            rawText: transcription.rawText,
            processedContent: transcription.processedContent,
            canonicalSummary: transcription.canonicalSummary,
            qualityProfile: transcription.qualityProfile,
            postProcessingPromptId: transcription.postProcessingPromptId,
            postProcessingPromptTitle: transcription.postProcessingPromptTitle,
            language: transcription.language,
            createdAt: transcription.createdAt,
            modelName: transcription.modelName,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcription.transcriptionDuration,
            postProcessingDuration: transcription.postProcessingDuration,
            postProcessingModel: transcription.postProcessingModel,
            meetingType: transcription.meetingType,
            meetingConversationState: transcription.meetingConversationState
        )

        try await storage.saveTranscription(updatedTranscription)
        if selectedId == selectedID || selectedTranscription?.id == selectedID {
            selectedTranscription = updatedTranscription
        }
    }

    private func sortedSegments(_ segments: [Transcription.Segment]) -> [Transcription.Segment] {
        segments.sorted(by: Self.segmentSortComparator)
    }

    private func postProcessingInput(for transcription: Transcription) -> String {
        let segments = sortedSegments(transcription.segments)
        guard !segments.isEmpty else {
            return transcription.rawText
        }

        return segments
            .map { segment in
                "[\(segment.startTime)-\(segment.endTime)] \(segment.speaker): \(segment.text)"
            }
            .joined(separator: "\n")
    }

    private func markPostProcessingStarted(for transcriptionID: UUID) {
        postProcessingByTranscriptionID.insert(transcriptionID)
        isProcessingAI = !postProcessingByTranscriptionID.isEmpty
    }

    private func markPostProcessingFinished(for transcriptionID: UUID) {
        postProcessingByTranscriptionID.remove(transcriptionID)
        isProcessingAI = !postProcessingByTranscriptionID.isEmpty
    }

    private func clearPostProcessingError(for transcriptionID: UUID) {
        postProcessingErrorByTranscriptionID.removeValue(forKey: transcriptionID)
    }
}
