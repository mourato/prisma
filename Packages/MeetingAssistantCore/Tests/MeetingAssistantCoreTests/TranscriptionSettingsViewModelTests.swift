import Combine
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class TranscriptionSettingsViewModelTests: XCTestCase {
    var viewModel: TranscriptionSettingsViewModel!
    var storage: MockStorageService!
    var meetingQAService: MockMeetingQAService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        storage = MockStorageService()
        meetingQAService = MockMeetingQAService()
        viewModel = TranscriptionSettingsViewModel(storage: storage, meetingQAService: meetingQAService)
        cancellables = []
    }

    override func tearDown() async throws {
        storage = nil
        meetingQAService = nil
        viewModel = nil
        cancellables = nil
    }

    func testLoadTranscriptions() async {
        // Given
        let mockId1 = UUID()
        let mockId2 = UUID()
        storage.mockTranscriptions = [
            Transcription(
                id: mockId1,
                meeting: Meeting(id: mockId1, app: .microsoftTeams, startTime: Date(), endTime: Date().addingTimeInterval(60)),
                segments: [],
                text: "Text 1",
                rawText: "Text 1"
            ),
            Transcription(
                id: mockId2,
                meeting: Meeting(id: mockId2, app: .zoom, startTime: Date(), endTime: Date().addingTimeInterval(120)),
                segments: [],
                text: "Text 2",
                rawText: "Text 2"
            ),
        ]

        // When
        await viewModel.loadTranscriptions()

        // Then
        XCTAssertEqual(viewModel.transcriptions.count, 2)
        let metadataById = Dictionary(uniqueKeysWithValues: viewModel.transcriptions.map { ($0.id, $0) })
        let teamsMetadata = metadataById[mockId1]
        let zoomMetadata = metadataById[mockId2]

        XCTAssertNotNil(teamsMetadata)
        XCTAssertNotNil(zoomMetadata)
        XCTAssertEqual(teamsMetadata?.appRawValue, MeetingApp.microsoftTeams.rawValue)
        XCTAssertEqual(teamsMetadata?.duration ?? 0, 60, accuracy: 0.1)
        XCTAssertEqual(zoomMetadata?.appRawValue, MeetingApp.zoom.rawValue)
        XCTAssertEqual(zoomMetadata?.duration ?? 0, 120, accuracy: 0.1)
    }

    func testSelectTranscriptionLoadsFullData() async {
        // Given
        let mockId = UUID()
        let fullTranscription = Transcription(
            id: mockId,
            meeting: Meeting(id: mockId, app: .microsoftTeams, startTime: Date(), endTime: Date()),
            segments: [Transcription.Segment(id: UUID(), speaker: "A", text: "Hello", startTime: 0, endTime: 5)],
            text: "Hello",
            rawText: "Hello"
        )
        storage.mockTranscriptions = [fullTranscription]
        await viewModel.loadTranscriptions()

        // When
        viewModel.selectedId = mockId

        // Wait for async loading
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Then
        XCTAssertNotNil(viewModel.selectedTranscription)
        XCTAssertEqual(viewModel.selectedTranscription?.id, mockId)
        XCTAssertEqual(viewModel.selectedTranscription?.segments.count, 1)
    }

    func testMatchSourceFilter() {
        // Given
        let mockId1 = UUID()
        let mockId2 = UUID()
        let metadata1 = TranscriptionMetadata(
            id: mockId1,
            meetingId: mockId1,
            appName: "Dictation",
            appRawValue: MeetingApp.unknown.rawValue,
            appBundleIdentifier: nil,
            startTime: Date(),
            createdAt: Date(),
            previewText: "",
            wordCount: 0,
            language: "en",
            isPostProcessed: false,
            duration: 60,
            audioFilePath: nil,
            inputSource: "Microphone"
        )
        let metadata2 = TranscriptionMetadata(
            id: mockId2,
            meetingId: mockId2,
            appName: "Imported",
            appRawValue: MeetingApp.importedFile.rawValue,
            appBundleIdentifier: nil,
            startTime: Date(),
            createdAt: Date(),
            previewText: "",
            wordCount: 0,
            language: "en",
            isPostProcessed: false,
            duration: 120,
            audioFilePath: nil,
            inputSource: "File"
        )

        viewModel.transcriptions = [metadata1, metadata2]

        // When/Then
        // Test .all
        viewModel.sourceFilter = .all
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 2)

        // Test .dictations (unknown only, excluding imported files)
        viewModel.sourceFilter = .dictations
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 1)
        XCTAssertEqual(viewModel.filteredTranscriptions.first?.id, mockId1)

        // Test .meetings (non-unknown and non-imported)
        viewModel.sourceFilter = .meetings
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 0)

        // Imported files remain visible under .all
        viewModel.sourceFilter = .all
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 2)
        XCTAssertTrue(viewModel.filteredTranscriptions.contains(where: { $0.id == mockId2 }))
    }

    func testAppFilterOptionsIncludesAllAndLoadedApps() {
        // Given
        let metadata1 = makeMetadata(
            appName: "Zoom",
            appRawValue: MeetingApp.zoom.rawValue,
            previewText: "Sprint planning"
        )
        let metadata2 = makeMetadata(
            appName: "Microsoft Teams",
            appRawValue: MeetingApp.microsoftTeams.rawValue,
            previewText: "Roadmap review"
        )
        viewModel.transcriptions = [metadata1, metadata2]

        // When
        let options = viewModel.appFilterOptions

        // Then
        XCTAssertEqual(options.first?.id, "__all_apps__")
        XCTAssertTrue(options.contains(where: { $0.id == "raw:\(MeetingApp.zoom.rawValue)" }))
        XCTAssertTrue(options.contains(where: { $0.id == "raw:\(MeetingApp.microsoftTeams.rawValue)" }))
    }

    func testFilteredTranscriptionsAppliesAppAndSearchFilters() {
        // Given
        let zoomMetadata = makeMetadata(
            appName: "Zoom",
            appRawValue: MeetingApp.zoom.rawValue,
            previewText: "Discussed quarterly results"
        )
        let teamsMetadata = makeMetadata(
            appName: "Microsoft Teams",
            appRawValue: MeetingApp.microsoftTeams.rawValue,
            previewText: "Reunião de planejamento"
        )
        viewModel.transcriptions = [zoomMetadata, teamsMetadata]

        // When
        viewModel.appFilterId = "raw:\(MeetingApp.microsoftTeams.rawValue)"
        viewModel.searchText = "reuniao"

        // Then
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 1)
        XCTAssertEqual(viewModel.filteredTranscriptions.first?.id, teamsMetadata.id)
    }

    func testAppFilterOptionsIncludeUnknownAppsByDisplayName() {
        // Given
        let codexMetadata = makeMetadata(
            appName: "Codex",
            appRawValue: MeetingApp.unknown.rawValue,
            previewText: "Discussing refinements"
        )
        let browserMetadata = makeMetadata(
            appName: "Arc Browser",
            appRawValue: MeetingApp.unknown.rawValue,
            previewText: "Planning meeting"
        )
        viewModel.transcriptions = [codexMetadata, browserMetadata]

        // When
        let options = viewModel.appFilterOptions

        // Then
        XCTAssertTrue(options.contains(where: { $0.displayName == "Codex" }))
        XCTAssertTrue(options.contains(where: { $0.displayName == "Arc Browser" }))
        XCTAssertFalse(options.contains(where: { $0.displayName == MeetingApp.unknown.displayName }))
    }

    func testFilteredTranscriptionsAppliesUnknownDisplayNameAppFilter() {
        // Given
        let codexMetadata = makeMetadata(
            appName: "Codex",
            appRawValue: MeetingApp.unknown.rawValue,
            previewText: "Implemented one two three"
        )
        let browserMetadata = makeMetadata(
            appName: "Arc Browser",
            appRawValue: MeetingApp.unknown.rawValue,
            previewText: "General notes"
        )
        viewModel.transcriptions = [codexMetadata, browserMetadata]
        let codexFilterOption = viewModel.appFilterOptions.first(where: { $0.displayName == "Codex" })

        // When
        viewModel.appFilterId = codexFilterOption?.id ?? "__all_apps__"

        // Then
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 1)
        XCTAssertEqual(viewModel.filteredTranscriptions.first?.id, codexMetadata.id)
    }

    private func makeMetadata(
        appName: String,
        appRawValue: String,
        previewText: String
    ) -> TranscriptionMetadata {
        let id = UUID()
        return TranscriptionMetadata(
            id: id,
            meetingId: id,
            appName: appName,
            appRawValue: appRawValue,
            appBundleIdentifier: nil,
            startTime: Date(),
            createdAt: Date(),
            previewText: previewText,
            wordCount: previewText.count,
            language: "en",
            isPostProcessed: false,
            duration: 60,
            audioFilePath: nil,
            inputSource: "Microphone"
        )
    }

    func testSubmitQuestionStoresGroundedAnswer() async {
        let transcription = Transcription(
            meeting: Meeting(id: UUID(), app: .googleMeet, startTime: Date(), endTime: Date().addingTimeInterval(60)),
            segments: [.init(speaker: "Ana", text: "Vamos lançar sexta.", startTime: 12, endTime: 16)],
            text: "Vamos lançar sexta.",
            rawText: "vamos lancar sexta"
        )

        viewModel.qaQuestion = "When are we launching?"
        meetingQAService.nextResponse = MeetingQAResponse(
            status: .answered,
            answer: "The team plans to launch on Friday.",
            evidence: [
                MeetingQAEvidence(
                    speaker: "Ana",
                    startTime: 12,
                    endTime: 16,
                    excerpt: "Vamos lançar sexta."
                ),
            ]
        )

        await viewModel.submitQuestion(for: transcription)

        XCTAssertEqual(meetingQAService.askCallCount, 1)
        XCTAssertEqual(viewModel.qaResponse?.status, .answered)
        XCTAssertEqual(viewModel.qaResponse?.evidence.count, 1)
        XCTAssertNil(viewModel.qaErrorMessage)
    }

    func testSubmitQuestionWithEmptyInputSetsValidationError() async {
        let transcription = Transcription(
            meeting: Meeting(id: UUID(), app: .googleMeet, startTime: Date(), endTime: Date().addingTimeInterval(60)),
            text: "Resumo",
            rawText: "Resumo"
        )

        viewModel.qaQuestion = "   "

        await viewModel.submitQuestion(for: transcription)

        XCTAssertEqual(meetingQAService.askCallCount, 0)
        XCTAssertEqual(viewModel.qaErrorMessage, "transcription.qa.error.empty_question".localized)
    }

    func testRetryLastQuestionAfterTimeoutUsesSameQuestion() async {
        let transcription = Transcription(
            meeting: Meeting(id: UUID(), app: .googleMeet, startTime: Date(), endTime: Date().addingTimeInterval(60)),
            segments: [.init(speaker: "Ana", text: "Vamos lançar sexta.", startTime: 12, endTime: 16)],
            text: "Vamos lançar sexta.",
            rawText: "vamos lancar sexta"
        )

        viewModel.qaQuestion = "When are we launching?"
        meetingQAService.nextError = .timeout

        await viewModel.submitQuestion(for: transcription)
        XCTAssertEqual(viewModel.qaErrorMessage, "transcription.qa.error.timeout".localized)

        meetingQAService.nextError = nil
        meetingQAService.nextResponse = MeetingQAResponse(
            status: .answered,
            answer: "Launch is Friday.",
            evidence: [
                .init(speaker: "Ana", startTime: 12, endTime: 16, excerpt: "Vamos lançar sexta."),
            ]
        )

        await viewModel.retryLastQuestion(for: transcription)

        XCTAssertEqual(meetingQAService.askCallCount, 2)
        XCTAssertEqual(meetingQAService.lastQuestion, "When are we launching?")
        XCTAssertEqual(viewModel.qaResponse?.answer, "Launch is Friday.")
        XCTAssertNil(viewModel.qaErrorMessage)
        XCTAssertEqual(viewModel.qaHistory(for: transcription.id).count, 2)
    }

    func testSubmitQuestion_AppendsHistoryForCurrentTranscription() async {
        let transcription = Transcription(
            meeting: Meeting(id: UUID(), app: .googleMeet, startTime: Date(), endTime: Date().addingTimeInterval(60)),
            text: "Summary",
            rawText: "Summary"
        )
        meetingQAService.nextResponse = MeetingQAResponse(
            status: .answered,
            answer: "Captured.",
            evidence: [.init(speaker: "A", startTime: 0, endTime: 1, excerpt: "Captured.")]
        )
        viewModel.qaQuestion = "Question 1"

        await viewModel.submitQuestion(for: transcription)

        let history = viewModel.qaHistory(for: transcription.id)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.question, "Question 1")
        XCTAssertEqual(history.first?.response?.answer, "Captured.")
    }

    func testLoadingDifferentTranscriptionResetsQuestionComposer() async {
        let id1 = UUID()
        let id2 = UUID()
        storage.mockTranscriptions = [
            Transcription(
                id: id1,
                meeting: Meeting(id: id1, app: .zoom, startTime: Date(), endTime: Date().addingTimeInterval(60)),
                text: "One",
                rawText: "One"
            ),
            Transcription(
                id: id2,
                meeting: Meeting(id: id2, app: .zoom, startTime: Date(), endTime: Date().addingTimeInterval(60)),
                text: "Two",
                rawText: "Two"
            ),
        ]
        await viewModel.loadTranscriptions()

        viewModel.qaQuestion = "Question"
        viewModel.selectedId = id1
        try? await Task.sleep(nanoseconds: 80_000_000)
        viewModel.selectedId = id2
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(viewModel.qaQuestion, "")
    }
}
