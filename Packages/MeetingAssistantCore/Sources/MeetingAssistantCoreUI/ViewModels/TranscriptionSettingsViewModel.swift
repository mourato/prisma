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

@MainActor
public class TranscriptionSettingsViewModel: ObservableObject {
    public struct AppFilterOption: Identifiable, Hashable, Sendable {
        public enum Scope: Hashable, Sendable {
            case all
            case appRawValue(String)
            case appBundleIdentifier(String)
            case appDisplayName(String)
        }

        public let id: String
        public let scope: Scope
        public let displayName: String
    }

    private enum FilterConstants {
        static let allAppsId = "__all_apps__"
        static let rawAppPrefix = "raw:"
        static let bundleAppPrefix = "bundle:"
        static let nameAppPrefix = "name:"
    }

    public struct QATurn: Identifiable, Hashable, Sendable {
        public let id: UUID
        public let question: String
        public let response: MeetingQAResponse?
        public let errorMessage: String?
        public let createdAt: Date

        public init(
            id: UUID = UUID(),
            question: String,
            response: MeetingQAResponse?,
            errorMessage: String?,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.question = question
            self.response = response
            self.errorMessage = errorMessage
            self.createdAt = createdAt
        }
    }

    @Published public var transcriptions: [TranscriptionMetadata] = []
    @Published public var selectedTranscription: Transcription?
    @Published public var selectedId: UUID? {
        didSet {
            if let id = selectedId {
                Task { await self.loadFullTranscription(id: id) }
            } else {
                Task {
                    self.selectedTranscription = nil
                }
            }
        }
    }

    @Published public var isProcessingAI = false
    @Published public private(set) var postProcessingByTranscriptionID: Set<UUID> = []
    @Published public private(set) var postProcessingErrorByTranscriptionID: [UUID: String] = [:]
    @Published public var qaQuestion = ""
    @Published public private(set) var qaResponse: MeetingQAResponse?
    @Published public private(set) var isAnsweringQuestion = false
    @Published public private(set) var qaErrorMessage: String?
    @Published public var qaHistoryByTranscription: [UUID: [QATurn]] = [:]
    @Published public var qaModelSelectionByTranscription: [UUID: MeetingQAModelSelection] = [:]

    @Published public var isLoading = true
    @Published public var sourceFilter: RecordingSourceFilter = .all
    @Published public var dateFilter: DateFilter = .today
    @Published public var searchText = ""
    @Published public var appFilterId = FilterConstants.allAppsId
    @Published public var errorMessage: String?

    let storage: StorageService
    private let recordingManager: RecordingManager
    private let meetingRepository: MeetingRepository
    let meetingQAService: any MeetingQAServiceProtocol
    let settings: AppSettingsStore
    let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "TranscriptionSettingsViewModel")
    private var lastAskedQuestion: String?
    private var lastQuestionTranscriptionId: UUID?

    private static let segmentSortComparator: (Transcription.Segment, Transcription.Segment) -> Bool = { lhs, rhs in
        if lhs.startTime != rhs.startTime {
            return lhs.startTime < rhs.startTime
        }
        if lhs.endTime != rhs.endTime {
            return lhs.endTime < rhs.endTime
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    public init(
        storage: StorageService = FileSystemStorageService.shared,
        recordingManager: RecordingManager = .shared,
        meetingRepository: MeetingRepository = CoreDataMeetingRepository(),
        meetingQAService: any MeetingQAServiceProtocol = MeetingQAService.shared,
        settings: AppSettingsStore = .shared
    ) {
        self.storage = storage
        self.recordingManager = recordingManager
        self.meetingRepository = meetingRepository
        self.meetingQAService = meetingQAService
        self.settings = settings
    }

    public var isMeetingQnAEnabled: Bool {
        settings.meetingQnAEnabled
    }

    public func canOpenMeetingConversation(for metadata: TranscriptionMetadata) -> Bool {
        metadata.supportsMeetingConversation
    }

    public func qaHistory(for transcriptionID: UUID) -> [QATurn] {
        qaHistoryByTranscription[transcriptionID] ?? []
    }

    public func effectiveMeetingQAModelSelection(for transcriptionID: UUID) -> MeetingQAModelSelection {
        if let override = qaModelSelectionByTranscription[transcriptionID],
           AIProvider(rawValue: override.providerRawValue) != nil,
           !override.modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return override
        }

        let defaults = settings.enhancementsAISelection
        return MeetingQAModelSelection(
            providerRawValue: defaults.provider.rawValue,
            modelID: defaults.selectedModel
        )
    }

    public var filteredTranscriptions: [TranscriptionMetadata] {
        let selectedAppScope = selectedAppFilterScope()
        return transcriptions.filter { transcription in
            let matchesSource = self.matchesSourceFilter(transcription)
            let matchesDate = self.dateFilter.contains(transcription.createdAt)
            let matchesApp = self.matchesAppFilter(transcription, scope: selectedAppScope)
            let matchesText = self.matchesSearchFilter(transcription)
            return matchesSource && matchesDate && matchesApp && matchesText
        }
    }

    public var appFilterOptions: [AppFilterOption] {
        let optionsById = transcriptions.reduce(into: [String: AppFilterOption]()) { result, transcription in
            guard let option = appFilterOption(for: transcription) else { return }
            result[option.id] = option
        }

        let allAppsOption = AppFilterOption(
            id: FilterConstants.allAppsId,
            scope: .all,
            displayName: "settings.transcriptions.filter_app_all".localized
        )

        let sortedAppOptions = optionsById.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        return [allAppsOption] + sortedAppOptions
    }

    /// Transcriptions grouped by date (start of day) for section headers.
    public var groupedTranscriptions: [Date: [TranscriptionMetadata]] {
        Dictionary(grouping: filteredTranscriptions) { metadata in
            Calendar.current.startOfDay(for: metadata.createdAt)
        }
    }

    /// Sorted list of dates for the group headers.
    public var sortedGroupDates: [Date] {
        groupedTranscriptions.keys.sorted(by: >)
    }

    private func matchesSourceFilter(_ transcription: TranscriptionMetadata) -> Bool {
        switch sourceFilter {
        case .all:
            true
        case .dictations:
            // Dictation = Unknown app source (menu bar dictation) AND not imported file.
            transcription.meetingApp == .unknown
        case .meetings:
            transcription.meetingApp.supportsMeetingConversation
        }
    }

    private func matchesAppFilter(_ transcription: TranscriptionMetadata, scope: AppFilterOption.Scope) -> Bool {
        switch scope {
        case .all:
            return true
        case let .appRawValue(appRawValue):
            return transcription.appRawValue == appRawValue
        case let .appBundleIdentifier(bundleIdentifier):
            let transcriptionBundleIdentifier = transcription.appBundleIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return transcriptionBundleIdentifier == bundleIdentifier
        case let .appDisplayName(displayName):
            return normalizedFilterValue(appDisplayName(for: transcription)) == displayName
        }
    }

    private func selectedAppFilterScope() -> AppFilterOption.Scope {
        guard appFilterId != FilterConstants.allAppsId else { return .all }

        if appFilterId.hasPrefix(FilterConstants.rawAppPrefix) {
            let rawValue = String(appFilterId.dropFirst(FilterConstants.rawAppPrefix.count))
            return rawValue.isEmpty ? .all : .appRawValue(rawValue)
        }

        if appFilterId.hasPrefix(FilterConstants.bundleAppPrefix) {
            let bundleIdentifier = String(appFilterId.dropFirst(FilterConstants.bundleAppPrefix.count))
            return bundleIdentifier.isEmpty ? .all : .appBundleIdentifier(bundleIdentifier)
        }

        if appFilterId.hasPrefix(FilterConstants.nameAppPrefix) {
            let displayName = String(appFilterId.dropFirst(FilterConstants.nameAppPrefix.count))
            return displayName.isEmpty ? .all : .appDisplayName(displayName)
        }

        return .all
    }

    private func matchesSearchFilter(_ transcription: TranscriptionMetadata) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let previewText = transcription.previewText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let appName = transcription.appName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        return previewText.contains(normalizedQuery) || appName.contains(normalizedQuery)
    }

    private func appDisplayName(for transcription: TranscriptionMetadata) -> String {
        let trimmedName = transcription.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        if let knownApp = MeetingApp(rawValue: transcription.appRawValue) {
            return knownApp.displayName
        }

        let trimmedRawValue = transcription.appRawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedRawValue.isEmpty ? MeetingApp.unknown.displayName : trimmedRawValue
    }

    private func appFilterOption(for transcription: TranscriptionMetadata) -> AppFilterOption? {
        let rawValue = transcription.appRawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = appDisplayName(for: transcription)

        if !rawValue.isEmpty, rawValue != MeetingApp.unknown.rawValue {
            return AppFilterOption(
                id: "\(FilterConstants.rawAppPrefix)\(rawValue)",
                scope: .appRawValue(rawValue),
                displayName: displayName
            )
        }

        let bundleIdentifier = transcription.appBundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return AppFilterOption(
                id: "\(FilterConstants.bundleAppPrefix)\(bundleIdentifier)",
                scope: .appBundleIdentifier(bundleIdentifier),
                displayName: displayName
            )
        }

        let normalizedDisplayName = normalizedFilterValue(displayName)
        guard !normalizedDisplayName.isEmpty else { return nil }
        return AppFilterOption(
            id: "\(FilterConstants.nameAppPrefix)\(normalizedDisplayName)",
            scope: .appDisplayName(normalizedDisplayName),
            displayName: displayName
        )
    }

    private func normalizedFilterValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    public func loadTranscriptions() async {
        isLoading = true
        do {
            let query = TranscriptionMetadataQuery(
                sourceFilter: sourceFilter,
                dateFilter: dateFilter,
                searchText: searchText,
                appRawValue: nil
            )

            let allTranscriptions = try await storage.loadMetadata(matching: query)
            // Filter out items with errors or verify integrity if needed.
            // Assuming errors in capture manifest as 0 duration or specific metadata flags if we had them.
            // For now, ensuring we don't show items that are clearly failed (e.g. 0 duration and no text)
            transcriptions = allTranscriptions.filter { !($0.duration == 0 && $0.previewText.isEmpty) }
            if !appFilterOptions.contains(where: { $0.id == appFilterId }) {
                appFilterId = FilterConstants.allAppsId
            }

            if let selectedId, !transcriptions.contains(where: { $0.id == selectedId }) {
                self.selectedId = nil
            }
        } catch {
            logger.error("Failed to load transcriptions: \(error.localizedDescription)")
            errorMessage = "settings.transcriptions.error_load".localized
        }
        isLoading = false
    }

    public func loadFullTranscription(id: UUID) async {
        do {
            if selectedTranscription?.id != id {
                resetQuestionState()
            }
            selectedTranscription = try await storage.loadTranscription(by: id)
            if let selectedTranscription {
                restoreMeetingConversationState(from: selectedTranscription)
            }
        } catch {
            logger.error("Failed to load full transcription: \(error.localizedDescription)")
        }
    }

    public func submitQuestion(for transcription: Transcription) async {
        let trimmedQuestion = qaQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            qaErrorMessage = "transcription.qa.error.empty_question".localized
            return
        }

        await askQuestion(trimmedQuestion, for: transcription)
    }

    public func retryLastQuestion(for transcription: Transcription) async {
        guard let lastAskedQuestion,
              lastQuestionTranscriptionId == transcription.id
        else {
            qaErrorMessage = "transcription.qa.error.no_retry_context".localized
            return
        }

        qaQuestion = lastAskedQuestion
        await askQuestion(lastAskedQuestion, for: transcription)
    }

    public func retryQuestion(_ question: String, for transcription: Transcription) async {
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

    private func resetQuestionState() {
        qaQuestion = ""
        qaResponse = nil
        qaErrorMessage = nil
        lastAskedQuestion = nil
        lastQuestionTranscriptionId = nil
    }

    public func clearQuestionComposer() {
        qaQuestion = ""
        qaErrorMessage = nil
    }

    private func appendQATurn(_ turn: QATurn, transcriptionID: UUID) {
        var turns = qaHistoryByTranscription[transcriptionID] ?? []
        turns.append(turn)
        qaHistoryByTranscription[transcriptionID] = turns
    }

    public func openRecordingsDirectory() {
        NSWorkspace.shared.open(storage.recordingsDirectory)
    }

    public func isPostProcessing(transcriptionID: UUID) -> Bool {
        postProcessingByTranscriptionID.contains(transcriptionID)
    }

    public func postProcessingError(for transcriptionID: UUID) -> String? {
        postProcessingErrorByTranscriptionID[transcriptionID]
    }

    public var availablePrompts: [PostProcessingPrompt] {
        AppSettingsStore.shared.allPrompts
    }

    public func availablePrompts(for metadata: TranscriptionMetadata) -> [PostProcessingPrompt] {
        if !metadata.supportsMeetingConversation {
            return AppSettingsStore.shared.dictationAvailablePrompts
        }
        return AppSettingsStore.shared.meetingAvailablePrompts
    }

    public func applyPostProcessing(prompt: PostProcessingPrompt, to transcription: Transcription) async {
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
            errorMessage = message
        }
    }

    public func renameSpeaker(
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
            errorMessage = "transcription.speaker.rename.error".localized
        }
    }

    public func deleteTranscription(_ metadata: TranscriptionMetadata) async {
        do {
            try await storage.deleteTranscription(by: metadata.id)
            if selectedId == metadata.id {
                selectedId = nil
            }
            await loadTranscriptions()
        } catch {
            logger.error("Failed to delete transcription: \(error.localizedDescription)")
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    public func retryTranscription(for metadata: TranscriptionMetadata) async {
        guard !recordingManager.isTranscribing else {
            return
        }

        do {
            guard let transcription = try await storage.loadTranscription(by: metadata.id) else {
                errorMessage = "transcription.retry.missing_transcription".localized
                return
            }

            guard let audioURL = transcription.audioURL else {
                errorMessage = "transcription.retry.missing_audio".localized
                return
            }

            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                errorMessage = "transcription.retry.missing_audio".localized
                return
            }

            await recordingManager.retryTranscription(for: transcription)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to retry transcription: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    public func updateSource(for metadata: TranscriptionMetadata, isMeeting: Bool) async {
        let app = MeetingApp(rawValue: metadata.appRawValue) ?? .unknown
        guard app != .importedFile else { return }
        guard app == .unknown || app == .manualMeeting else { return }

        let targetApp: DomainMeetingApp = isMeeting ? .manualMeeting : .unknown

        do {
            let existing = try await meetingRepository.fetchMeeting(by: metadata.meetingId)
            let endTime = metadata.duration > 0
                ? metadata.startTime.addingTimeInterval(metadata.duration)
                : nil

            let updatedMeeting = MeetingEntity(
                id: metadata.meetingId,
                app: targetApp,
                appBundleIdentifier: existing?.appBundleIdentifier ?? metadata.appBundleIdentifier,
                appDisplayName: existing?.appDisplayName ?? metadata.appName,
                startTime: existing?.startTime ?? metadata.startTime,
                endTime: existing?.endTime ?? endTime,
                audioFilePath: existing?.audioFilePath ?? metadata.audioFilePath
            )

            try await meetingRepository.updateMeeting(updatedMeeting)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to update recording source: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
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
