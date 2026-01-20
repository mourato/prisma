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

    func testLoadTranscriptions() async throws {
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
        XCTAssertEqual(viewModel.transcriptions[0].id, mockId1)
        // appRawValue for Teams is "microsoft-teams" (from MeetingApp enum)
        XCTAssertEqual(viewModel.transcriptions[0].appRawValue, MeetingApp.microsoftTeams.rawValue)
        XCTAssertEqual(viewModel.transcriptions[0].duration, 60, accuracy: 0.1)
        XCTAssertEqual(viewModel.transcriptions[1].id, mockId2)
        XCTAssertEqual(viewModel.transcriptions[1].appRawValue, MeetingApp.zoom.rawValue)
        XCTAssertEqual(viewModel.transcriptions[1].duration, 120, accuracy: 0.1)
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

    func testMatchSourceFilter() async {
        // Given
        let mockId1 = UUID()
        let mockId2 = UUID()
        let metadata1 = TranscriptionMetadata(
            id: mockId1,
            meetingId: mockId1,
            appName: "Teams",
            appRawValue: MeetingApp.microsoftTeams.rawValue,
            startTime: Date(),
            createdAt: Date(),
            previewText: "",
            language: "en",
            isPostProcessed: false,
            duration: 60
        )
        let metadata2 = TranscriptionMetadata(
            id: mockId2,
            meetingId: mockId2,
            appName: "Imported",
            appRawValue: MeetingApp.importedFile.rawValue,
            startTime: Date(),
            createdAt: Date(),
            previewText: "",
            language: "en",
            isPostProcessed: false,
            duration: 120
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
}
