import Foundation
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class MeetingNotesPersistenceTests: XCTestCase {
    private var viewModel: TranscriptionSettingsViewModel!
    private var storage: MockStorageService!
    private var meetingRepository: MockMeetingRepository!
    private var meetingQAService: MockMeetingQAService!
    private var richTextStore: MeetingNotesRichTextStore!
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        storage = MockStorageService()
        meetingRepository = MockMeetingRepository()
        meetingQAService = MockMeetingQAService()
        suiteName = "MeetingNotesPersistenceTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        richTextStore = MeetingNotesRichTextStore(userDefaults: userDefaults)
        viewModel = TranscriptionSettingsViewModel(
            storage: storage,
            meetingRepository: meetingRepository,
            meetingQAService: meetingQAService,
            meetingNotesRichTextStore: richTextStore
        )
    }

    override func tearDown() async throws {
        if let suiteName {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        suiteName = nil
        viewModel = nil
        storage = nil
        meetingRepository = nil
        meetingQAService = nil
        richTextStore = nil
        userDefaults = nil
    }

    func testUpdateMeetingNotes_UpdatesExistingEntryAndPersists() async throws {
        let transcription = makeTranscription(
            contextItems: [
                .init(source: .meetingNotes, text: "Old notes"),
                .init(source: .clipboard, text: "Clipboard context"),
            ]
        )
        storage.mockTranscriptions = [transcription]
        viewModel.selectedTranscription = transcription

        await viewModel.updateMeetingNotes("Updated notes", in: transcription.id)

        let saved = try XCTUnwrap(storage.savedTranscriptions.last)
        let meetingNotes = saved.contextItems.filter { $0.source == .meetingNotes }
        XCTAssertEqual(meetingNotes.count, 1)
        XCTAssertEqual(meetingNotes.first?.text, "Updated notes")
        XCTAssertTrue(saved.contextItems.contains { $0.source == .clipboard && $0.text == "Clipboard context" })
    }

    func testUpdateMeetingNotes_CreatesEntryWhenMissing() async throws {
        let transcription = makeTranscription(
            contextItems: [
                .init(source: .activeApp, text: "Zoom"),
            ]
        )
        storage.mockTranscriptions = [transcription]
        viewModel.selectedTranscription = transcription

        await viewModel.updateMeetingNotes("New notes", in: transcription.id)

        let saved = try XCTUnwrap(storage.savedTranscriptions.last)
        let meetingNotes = saved.contextItems.filter { $0.source == .meetingNotes }
        XCTAssertEqual(meetingNotes.count, 1)
        XCTAssertEqual(meetingNotes.first?.text, "New notes")
        XCTAssertTrue(saved.contextItems.contains { $0.source == .activeApp && $0.text == "Zoom" })
    }

    func testUpdateMeetingNotes_RemovesEntriesWhenCleared() async throws {
        let transcription = makeTranscription(
            contextItems: [
                .init(source: .meetingNotes, text: "Meeting notes"),
                .init(source: .focusedText, text: "Focused context"),
            ]
        )
        storage.mockTranscriptions = [transcription]
        viewModel.selectedTranscription = transcription

        await viewModel.updateMeetingNotes("   ", in: transcription.id)

        let saved = try XCTUnwrap(storage.savedTranscriptions.last)
        XCTAssertTrue(saved.contextItems.allSatisfy { $0.source != .meetingNotes })
        XCTAssertTrue(saved.contextItems.contains { $0.source == .focusedText && $0.text == "Focused context" })
    }

    func testUpdateMeetingNotes_CollapsesDuplicateEntriesIntoSingleItem() async throws {
        let transcription = makeTranscription(
            contextItems: [
                .init(source: .meetingNotes, text: "Old notes 1"),
                .init(source: .activeApp, text: "Slack"),
                .init(source: .meetingNotes, text: "Old notes 2"),
            ]
        )
        storage.mockTranscriptions = [transcription]
        viewModel.selectedTranscription = transcription

        await viewModel.updateMeetingNotes("Canonical notes", in: transcription.id)

        let saved = try XCTUnwrap(storage.savedTranscriptions.last)
        let meetingNotes = saved.contextItems.filter { $0.source == .meetingNotes }
        XCTAssertEqual(meetingNotes.count, 1)
        XCTAssertEqual(meetingNotes.first?.text, "Canonical notes")
        XCTAssertTrue(saved.contextItems.contains { $0.source == .activeApp && $0.text == "Slack" })
    }

    func testUpdateMeetingNotes_UpdatesSelectedTranscriptionAndPreservesOtherContextItems() async throws {
        let transcription = makeTranscription(
            contextItems: [
                .init(source: .meetingNotes, text: "Old notes"),
                .init(source: .calendarEvent, text: "Planning sync"),
                .init(source: .windowTitle, text: "Roadmap"),
            ]
        )
        storage.mockTranscriptions = [transcription]
        viewModel.selectedId = transcription.id
        viewModel.selectedTranscription = transcription

        await viewModel.updateMeetingNotes("Refined notes", in: transcription.id)

        let selected = try XCTUnwrap(viewModel.selectedTranscription)
        XCTAssertEqual(selected.id, transcription.id)
        XCTAssertEqual(selected.contextItems.filter { $0.source == .meetingNotes }.count, 1)
        XCTAssertEqual(
            selected.contextItems.first(where: { $0.source == .meetingNotes })?.text,
            "Refined notes"
        )
        XCTAssertTrue(selected.contextItems.contains { $0.source == .calendarEvent && $0.text == "Planning sync" })
        XCTAssertTrue(selected.contextItems.contains { $0.source == .windowTitle && $0.text == "Roadmap" })
    }

    func testUpdateMeetingNotes_PersistsRichTextSidecar() async throws {
        let transcription = makeTranscription(
            contextItems: [
                .init(source: .meetingNotes, text: "Old notes"),
            ]
        )
        storage.mockTranscriptions = [transcription]
        viewModel.selectedTranscription = transcription

        let richData = Data([0x7B, 0x5C, 0x72, 0x74, 0x66])
        await viewModel.updateMeetingNotes(
            MeetingNotesContent(plainText: "Rich notes", richTextRTFData: richData),
            in: transcription.id
        )

        XCTAssertEqual(richTextStore.transcriptionNotesRTFData(for: transcription.id), richData)
    }

    func testUpdateMeetingNotes_ClearsRichTextSidecarWhenNotesAreCleared() async throws {
        let transcription = makeTranscription(
            contextItems: [
                .init(source: .meetingNotes, text: "Old notes"),
            ]
        )
        storage.mockTranscriptions = [transcription]
        viewModel.selectedTranscription = transcription

        richTextStore.saveTranscriptionNotesRTFData(Data([0x7B, 0x5C, 0x72, 0x74, 0x66]), for: transcription.id)

        await viewModel.updateMeetingNotes(
            MeetingNotesContent(plainText: "   ", richTextRTFData: Data([0x01, 0x02])),
            in: transcription.id
        )

        XCTAssertNil(richTextStore.transcriptionNotesRTFData(for: transcription.id))
    }

    private func makeTranscription(contextItems: [TranscriptionContextItem]) -> Transcription {
        let id = UUID()
        return Transcription(
            id: id,
            meeting: Meeting(
                id: id,
                app: .zoom,
                startTime: Date(),
                endTime: Date().addingTimeInterval(60)
            ),
            contextItems: contextItems,
            segments: [.init(speaker: "Speaker 1", text: "Content", startTime: 0, endTime: 5)],
            text: "Content",
            rawText: "Content"
        )
    }
}
