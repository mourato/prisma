// CoreDataRepositoryTests - Testes de integração para repositórios CoreData
// Usa banco de dados em memória para isolamento

import CoreData
@testable import MeetingAssistantCore
import XCTest

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

    func testSaveMeeting_ClearsTitleAndCalendarLinkForNonMeetingApps() async throws {
        let meeting = MeetingEntity(
            id: UUID(),
            app: .importedFile,
            title: "Imported title",
            linkedCalendarEvent: MeetingCalendarEventSnapshot(
                eventIdentifier: "calendar-1",
                title: "Calendar title",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3_600),
                location: "Room",
                notes: "Notes",
                attendees: ["Alice"]
            ),
            startTime: Date()
        )

        try await meetingRepo.saveMeeting(meeting)
        let fetched = try await meetingRepo.fetchMeeting(by: meeting.id)

        XCTAssertNotNil(fetched)
        XCTAssertNil(fetched?.title)
        XCTAssertNil(fetched?.linkedCalendarEvent)
        XCTAssertNil(fetched?.preferredTitle)
    }

    func testSanitizeMeetingOnlyPresentationDataIfNeeded_CleansLegacyNonMeetingRows() async throws {
        let checkpointKey = "coredata.tests.non_meeting_sanitizer.\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: checkpointKey)

        let meetingID = UUID()
        try await stack.performBackgroundTask { context in
            let meeting = MeetingMO(context: context)
            meeting.id = meetingID
            meeting.appRawValue = DomainMeetingApp.importedFile.rawValue
            meeting.title = "Legacy imported title"
            meeting.linkedCalendarEventData = try JSONEncoder().encode(
                MeetingCalendarEventSnapshot(
                    eventIdentifier: "calendar-legacy",
                    title: "Legacy calendar title",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3_600),
                    attendees: []
                )
            )
            meeting.startTime = Date()
            try context.save()
        }

        await stack.sanitizeMeetingOnlyPresentationDataIfNeeded(checkpointKey: checkpointKey)
        let fetched = try await meetingRepo.fetchMeeting(by: meetingID)

        XCTAssertNotNil(fetched)
        XCTAssertNil(fetched?.title)
        XCTAssertNil(fetched?.linkedCalendarEvent)
        XCTAssertNil(fetched?.preferredTitle)
    }

    // MARK: - Transcription Repository Tests

    func testSaveAndFetchTranscription() async throws {
        // Given
        let meeting = MeetingEntity(app: .googleMeet)
        try await meetingRepo.saveMeeting(meeting)

        let config = TranscriptionEntity.Configuration(
            text: "Hi",
            rawText: "Hi",
            segments: [
                TranscriptionEntity.Segment(speaker: "A", text: "Hi", startTime: 0, endTime: 1),
            ]
        )
        let transcription = TranscriptionEntity(meeting: meeting, config: config)

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

    func testSaveAndFetchTranscription_WithCanonicalSummary() async throws {
        // Given
        let meeting = MeetingEntity(app: .googleMeet)
        try await meetingRepo.saveMeeting(meeting)

        let summary = CanonicalSummary(
            title: "Project Status",
            summary: "Project status is on track.",
            keyPoints: ["Milestone A completed"],
            decisions: ["Ship beta next week"],
            actionItems: [.init(title: "Prepare release notes", owner: "PM")],
            openQuestions: ["Do we need a migration guide?"],
            trustFlags: .init(
                isGroundedInTranscript: true,
                containsSpeculation: false,
                isHumanReviewed: true,
                confidenceScore: 0.92
            )
        )

        var config = TranscriptionEntity.Configuration(text: "Raw text", rawText: "Raw text")
        config.canonicalSummary = summary
        let transcription = TranscriptionEntity(meeting: meeting, config: config)

        // When
        try await transcriptionRepo.saveTranscription(transcription)
        let fetched = try await transcriptionRepo.fetchTranscription(by: transcription.id)

        // Then
        XCTAssertEqual(fetched?.canonicalSummary?.schemaVersion, CanonicalSummary.currentSchemaVersion)
        XCTAssertEqual(fetched?.canonicalSummary?.summary, "Project status is on track.")
        XCTAssertEqual(fetched?.canonicalSummary?.trustFlags.isGroundedInTranscript, true)
        XCTAssertEqual(fetched?.canonicalSummary?.trustFlags.confidenceScore ?? -1, 0.92, accuracy: 0.001)
    }

    func testSaveTranscription_NonMeetingMetadataDoesNotExposeTitleOrCalendarFallback() async throws {
        let meeting = MeetingEntity(
            id: UUID(),
            app: .importedFile,
            title: "Imported title",
            linkedCalendarEvent: MeetingCalendarEventSnapshot(
                eventIdentifier: "calendar-2",
                title: "Calendar fallback",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3_600),
                attendees: []
            ),
            startTime: Date()
        )
        try await meetingRepo.saveMeeting(meeting)

        let transcription = TranscriptionEntity(
            meeting: meeting,
            config: .init(text: "Imported transcript", rawText: "Imported transcript")
        )

        try await transcriptionRepo.saveTranscription(transcription)

        let fetched = try await transcriptionRepo.fetchTranscription(by: transcription.id)
        let metadata = try await transcriptionRepo.fetchAllMetadata()

        XCTAssertNil(fetched?.meeting.title)
        XCTAssertNil(fetched?.meeting.linkedCalendarEvent)
        XCTAssertNil(fetched?.meeting.preferredTitle)
        XCTAssertNil(metadata.first?.meetingTitle)
    }

    func testFetchTranscriptionsForMeeting() async throws {
        // Given
        let meeting = MeetingEntity(app: .googleMeet)
        try await meetingRepo.saveMeeting(meeting)

        let config1 = TranscriptionEntity.Configuration(text: "T1", rawText: "T1")
        let config2 = TranscriptionEntity.Configuration(text: "T2", rawText: "T2")
        let t1 = TranscriptionEntity(meeting: meeting, config: config1)
        let t2 = TranscriptionEntity(meeting: meeting, config: config2)
        try await transcriptionRepo.saveTranscription(t1)
        try await transcriptionRepo.saveTranscription(t2)

        // When
        let results = try await transcriptionRepo.fetchTranscriptions(for: meeting.id)

        // Then
        XCTAssertEqual(results.count, 2)
    }

    func testSaveTranscription_RejectsInvalidCanonicalSummary() async throws {
        // Given
        let meeting = MeetingEntity(app: .googleMeet)
        try await meetingRepo.saveMeeting(meeting)

        let invalidSummary = CanonicalSummary(
            schemaVersion: 0,
            title: "",
            summary: "",
            trustFlags: .init(confidenceScore: 1.2)
        )

        var config = TranscriptionEntity.Configuration(text: "Raw text", rawText: "Raw text")
        config.canonicalSummary = invalidSummary
        let transcription = TranscriptionEntity(meeting: meeting, config: config)

        // When / Then
        do {
            try await transcriptionRepo.saveTranscription(transcription)
            XCTFail("Expected validation error for canonical summary payload")
        } catch let error as CanonicalSummaryValidationError {
            XCTAssertEqual(error, .unsupportedSchemaVersion(0))
        }
    }
}
