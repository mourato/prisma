import Foundation
@testable import MeetingAssistantCore
import XCTest

final class TranscribeAudioUseCaseMacroMockingTests: XCTestCase {
    func testExecuteSuccess_SavesTranscription() async throws {
        let transcriptionRepository = MeetingAssistantCore.MacroMockTranscriptionRepository()
        let storageRepository = MeetingAssistantCore.MacroMockTranscriptionStorageRepository()

        transcriptionRepository.healthCheckHandler = { () async throws -> Bool in true }

        let response = DomainTranscriptionResponse(
            text: "Hello world",
            language: "en",
            durationSeconds: 1.0,
            model: "test-model",
            processedAt: "now",
            segments: []
        )

        transcriptionRepository.transcribeHandler = { _, _ in response }

        var saved: [TranscriptionEntity] = []
        storageRepository.saveTranscriptionHandler = { transcription in
            saved.append(transcription)
        }

        let useCase = TranscribeAudioUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionStorageRepository: storageRepository,
            postProcessingRepository: nil
        )

        let meeting = MeetingEntity(app: .googleMeet)
        let audioURL = URL(fileURLWithPath: "/tmp/test.wav")

        let transcription = try await useCase.execute(audioURL: audioURL, meeting: meeting)

        XCTAssertEqual(transcription.text, "Hello world")
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(transcriptionRepository.healthCheckCallCount, 1)
        XCTAssertEqual(transcriptionRepository.transcribeCalls.count, 1)
    }
}
