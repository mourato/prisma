// DomainLayerTests - Testes unitários para os casos de uso do domínio
// Usando Cuckoo para mocks automáticos

import Cuckoo
@testable import MeetingAssistantCore
import XCTest

final class DomainLayerTests: XCTestCase {
    var mockRecordingRepo: MockRecordingRepository?
    var mockAudioFileRepo: MockAudioFileRepository?
    var mockMeetingRepo: MockMeetingRepository?
    var mockTranscriptionRepo: MockTranscriptionRepository?
    var mockTranscriptionStorageRepo: MockTranscriptionStorageRepository?
    var mockPostProcessingRepo: MockPostProcessingRepository?

    override func setUp() {
        super.setUp()
        self.mockRecordingRepo = MockRecordingRepository()
        self.mockAudioFileRepo = MockAudioFileRepository()
        self.mockMeetingRepo = MockMeetingRepository()
        self.mockTranscriptionRepo = MockTranscriptionRepository()
        self.mockTranscriptionStorageRepo = MockTranscriptionStorageRepository()
        self.mockPostProcessingRepo = MockPostProcessingRepository()
    }

    override func tearDown() {
        self.mockRecordingRepo = nil
        self.mockAudioFileRepo = nil
        self.mockMeetingRepo = nil
        self.mockTranscriptionRepo = nil
        self.mockTranscriptionStorageRepo = nil
        self.mockPostProcessingRepo = nil
        super.tearDown()
    }

    // MARK: - StartRecordingUseCase Tests

    func testStartRecordingSuccess() async throws {
        // Given
        guard let mockRecordingRepo = self.mockRecordingRepo,
              let mockAudioFileRepo = self.mockAudioFileRepo,
              let mockMeetingRepo = self.mockMeetingRepo
        else {
            return XCTFail("Mocks not initialized")
        }

        let useCase = StartRecordingUseCase(
            recordingRepository: mockRecordingRepo,
            audioFileRepository: mockAudioFileRepo,
            meetingRepository: mockMeetingRepo
        )
        let meeting = MeetingEntity(app: .googleMeet)
        let expectedURL = URL(fileURLWithPath: "/tmp/test.wav")

        stub(mockRecordingRepo) { stub in
            when(stub.hasPermission()).then { _ in true }
            when(stub.startRecording(to: any(), retryCount: any())).then { _ in }
        }
        stub(mockAudioFileRepo) { stub in
            when(stub.generateAudioFileURL(for: any())).thenReturn(expectedURL)
        }
        stub(mockMeetingRepo) { stub in
            when(stub.updateMeeting(any())).then { _ in }
        }

        // When
        let resultURL = try await useCase.execute(for: meeting)

        // Then
        XCTAssertEqual(resultURL, expectedURL)
        verify(mockRecordingRepo).hasPermission()
        verify(mockRecordingRepo).startRecording(to: equal(to: expectedURL), retryCount: 3)
        verify(mockMeetingRepo).updateMeeting(any())
    }

    func testStartRecordingPermissionDenied() async {
        // Given
        guard let mockRecordingRepo = self.mockRecordingRepo,
              let mockAudioFileRepo = self.mockAudioFileRepo,
              let mockMeetingRepo = self.mockMeetingRepo
        else {
            return XCTFail("Mocks not initialized")
        }

        let useCase = StartRecordingUseCase(
            recordingRepository: mockRecordingRepo,
            audioFileRepository: mockAudioFileRepo,
            meetingRepository: mockMeetingRepo
        )
        let meeting = MeetingEntity(app: .googleMeet)

        stub(mockRecordingRepo) { stub in
            when(stub.hasPermission()).then { _ in false }
        }

        // When/Then
        do {
            _ = try await useCase.execute(for: meeting)
            XCTFail("Should throw permissionDenied")
        } catch RecordingError.permissionDenied {
            // Success
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - TranscribeAudioUseCase Tests

    func testTranscribeAudioSuccess() async throws {
        // Given
        guard let mockTranscriptionRepo = self.mockTranscriptionRepo,
              let mockTranscriptionStorageRepo = self.mockTranscriptionStorageRepo,
              let mockPostProcessingRepo = self.mockPostProcessingRepo
        else {
            return XCTFail("Mocks not initialized")
        }

        let useCase = TranscribeAudioUseCase(
            transcriptionRepository: mockTranscriptionRepo,
            transcriptionStorageRepository: mockTranscriptionStorageRepo,
            postProcessingRepository: mockPostProcessingRepo
        )
        let meeting = MeetingEntity(app: .googleMeet)
        let audioURL = URL(fileURLWithPath: "/tmp/test.wav")
        let response = DomainTranscriptionResponse(
            text: "Hello world",
            language: "en",
            durationSeconds: 5.0,
            model: "test-model",
            processedAt: "now"
        )

        stub(mockTranscriptionRepo) { stub in
            when(stub.healthCheck()).then { _ in true }
            when(
                stub.transcribe(
                    audioURL: any(),
                    onProgress: any(((@Sendable (Double) -> Void)?).self)
                )
            ).thenReturn(response)
        }
        stub(mockTranscriptionStorageRepo) { stub in
            when(stub.saveTranscription(any())).then { _ in }
        }

        // When
        let transcription = try await useCase.execute(audioURL: audioURL, meeting: meeting)

        // Then
        XCTAssertEqual(transcription.text, "Hello world")
        XCTAssertEqual(transcription.meeting.id, meeting.id)
        verify(mockTranscriptionRepo).healthCheck()
        verify(mockTranscriptionRepo).transcribe(
            audioURL: equal(to: audioURL),
            onProgress: any(((@Sendable (Double) -> Void)?).self)
        )
        verify(mockTranscriptionStorageRepo).saveTranscription(any())
    }
}
