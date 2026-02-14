import Combine
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class TranscriptionSettingsViewModelTests: XCTestCase {
    var viewModel: TranscriptionSettingsViewModel!
    var storage: MockStorageService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        storage = MockStorageService()
        viewModel = TranscriptionSettingsViewModel(storage: storage)
        cancellables = []
    }

    override func tearDown() async throws {
        storage = nil
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

        // Test .dictations (appRawValue != importedFile)
        viewModel.sourceFilter = .dictations
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 1)
        XCTAssertEqual(viewModel.filteredTranscriptions.first?.id, mockId1)

        // Test .manualImports (appRawValue == importedFile)
        viewModel.sourceFilter = .manualImports
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 1)
        XCTAssertEqual(viewModel.filteredTranscriptions.first?.id, mockId2)
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
        XCTAssertTrue(options.contains(where: { $0.id == MeetingApp.zoom.rawValue }))
        XCTAssertTrue(options.contains(where: { $0.id == MeetingApp.microsoftTeams.rawValue }))
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
        viewModel.appFilterId = MeetingApp.microsoftTeams.rawValue
        viewModel.searchText = "reuniao"

        // Then
        XCTAssertEqual(viewModel.filteredTranscriptions.count, 1)
        XCTAssertEqual(viewModel.filteredTranscriptions.first?.id, teamsMetadata.id)
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
}
