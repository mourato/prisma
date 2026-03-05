@testable import MeetingAssistantCore
import XCTest

@MainActor
final class MetricsDashboardViewModelTests: XCTestCase {
    func testLoad_RefreshesAfterFirstLoadEvenWhenAlreadyLoaded() async {
        let storage = MockStorageService()
        storage.mockTranscriptions = [
            makeTranscription(wordCount: 3),
        ]
        let viewModel = MetricsDashboardViewModel(storage: storage)

        await viewModel.load()
        XCTAssertEqual(viewModel.summary.sessionsRecorded, 1)
        XCTAssertEqual(viewModel.summary.wordsDictated, 3)

        storage.mockTranscriptions.append(makeTranscription(wordCount: 4))

        await viewModel.load()

        XCTAssertEqual(viewModel.summary.sessionsRecorded, 2)
        XCTAssertEqual(viewModel.summary.wordsDictated, 7)
    }

    func testHandleTranscriptionSaved_UpsertsSavedTranscriptionData() async {
        let storage = MockStorageService()
        let first = makeTranscription(wordCount: 2)
        let second = makeTranscription(wordCount: 5)
        storage.mockTranscriptions = [first]

        let viewModel = MetricsDashboardViewModel(storage: storage)
        await viewModel.load()
        XCTAssertEqual(viewModel.summary.sessionsRecorded, 1)

        storage.mockTranscriptions.append(second)
        let notification = Notification(
            name: .meetingAssistantTranscriptionSaved,
            object: nil,
            userInfo: [AppNotifications.UserInfoKey.transcriptionId: second.id.uuidString]
        )
        await viewModel.handleTranscriptionSaved(notification)

        XCTAssertEqual(viewModel.summary.sessionsRecorded, 2)
        XCTAssertEqual(viewModel.summary.wordsDictated, 7)
        XCTAssertTrue(viewModel.dailyBuckets.contains { $0.words >= 7 })
    }

    func testHandleTranscriptionSaved_MissingIDFallsBackToRefresh() async {
        let storage = MockStorageService()
        storage.mockTranscriptions = [
            makeTranscription(wordCount: 3),
        ]
        let viewModel = MetricsDashboardViewModel(storage: storage)

        await viewModel.load()
        XCTAssertEqual(viewModel.summary.sessionsRecorded, 1)

        storage.mockTranscriptions.append(makeTranscription(wordCount: 6))
        let notification = Notification(name: .meetingAssistantTranscriptionSaved)
        await viewModel.handleTranscriptionSaved(notification)

        XCTAssertEqual(viewModel.summary.sessionsRecorded, 2)
        XCTAssertEqual(viewModel.summary.wordsDictated, 9)
    }

    private func makeTranscription(wordCount: Int) -> Transcription {
        let words = Array(repeating: "word", count: max(wordCount, 1)).joined(separator: " ")
        let start = Date()
        let end = start.addingTimeInterval(60)
        let meeting = Meeting(
            id: UUID(),
            app: .microsoftTeams,
            startTime: start,
            endTime: end
        )

        return Transcription(
            id: UUID(),
            meeting: meeting,
            text: words,
            rawText: words,
            createdAt: start
        )
    }
}
