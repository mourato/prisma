// CoreDataRepositoryTests - Testes de integração para repositórios CoreData
// Usa banco de dados em memória para isolamento

import XCTest
import CoreData
@testable import MeetingAssistantCore

final class CoreDataRepositoryTests: XCTestCase {
    var stack: CoreDataStack!
    var meetingRepo: CoreDataMeetingRepository!
    var transcriptionRepo: CoreDataTranscriptionStorageRepository!

    override func setUp() {
        super.setUp()
        // Usar banco em memória para testes
        stack = CoreDataStack(name: "MeetingAssistantTests", inMemory: true)
        meetingRepo = CoreDataMeetingRepository(stack: stack)
        transcriptionRepo = CoreDataTranscriptionStorageRepository(stack: stack)
    }

    override func tearDown() {
        stack = nil
        meetingRepo = nil
        transcriptionRepo = nil
        super.tearDown()
    }

    // MARK: - Meeting Repository Tests

    func testSaveAndFetchMeeting() async throws {
        // Given
        let meeting = MeetingEntity(
            id: UUID(),
            app: .slack,
            startTime: Date(),
            audioFilePath: "/tmp/test.wav"
        )

        // When
        try await meetingRepo.saveMeeting(meeting)
        let fetched = try await meetingRepo.fetchMeeting(by: meeting.id)

        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, meeting.id)
        XCTAssertEqual(fetched?.app, .slack)
        XCTAssertEqual(fetched?.audioFilePath, "/tmp/test.wav")
    }

    func testFetchAllMeetings() async throws {
        // Given
        let m1 = MeetingEntity(app: .zoom)
        let m2 = MeetingEntity(app: .microsoftTeams)
        try await meetingRepo.saveMeeting(m1)
        try await meetingRepo.saveMeeting(m2)

        // When
        let all = try await meetingRepo.fetchAllMeetings()

        // Then
        XCTAssertEqual(all.count, 2)
    }

    func testDeleteMeeting() async throws {
        // Given
        let meeting = MeetingEntity(app: .slack)
        try await meetingRepo.saveMeeting(meeting)

        // When
        try await meetingRepo.deleteMeeting(by: meeting.id)
        let fetched = try await meetingRepo.fetchMeeting(by: meeting.id)

        // Then
        XCTAssertNil(fetched)
    }

    // MARK: - Transcription Repository Tests

    func testSaveAndFetchTranscription() async throws {
        // Given
        let meeting = MeetingEntity(app: .googleMeet)
        try await meetingRepo.saveMeeting(meeting)

        let transcription = TranscriptionEntity(
            id: UUID(),
            meeting: meeting,
            segments: [
                TranscriptionEntity.Segment(speaker: "A", text: "Hi", startTime: 0, endTime: 1)
            ],
            text: "Hi",
            rawText: "Hi"
        )

        // When
        try await transcriptionRepo.saveTranscription(transcription)
        let fetched = try await transcriptionRepo.fetchTranscription(by: transcription.id)

        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, transcription.id)
        XCTAssertEqual(fetched?.meeting.id, meeting.id)
        XCTAssertEqual(fetched?.segments.count, 1)
        XCTAssertEqual(fetched?.segments.first?.text, "Hi")
    }

    func testFetchTranscriptionsForMeeting() async throws {
        // Given
        let meeting = MeetingEntity(app: .googleMeet)
        try await meetingRepo.saveMeeting(meeting)

        let t1 = TranscriptionEntity(meeting: meeting, text: "T1", rawText: "T1")
        let t2 = TranscriptionEntity(meeting: meeting, text: "T2", rawText: "T2")
        try await transcriptionRepo.saveTranscription(t1)
        try await transcriptionRepo.saveTranscription(t2)

        // When
        let results = try await transcriptionRepo.fetchTranscriptions(for: meeting.id)

        // Then
        XCTAssertEqual(results.count, 2)
    }
}