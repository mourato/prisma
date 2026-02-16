import Foundation
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreDomain
import XCTest

final class TranscribeAudioPostProcessingTests: XCTestCase {
    func testExecuteWithPrompt_UsesPromptOverloadAndStoresProcessedText() async throws {
        let transcriptionRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionRepository()
        let storageRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionStorageRepository()
        let postProcessingRepository = MeetingAssistantCoreDomain.MacroMockPostProcessingRepository()

        transcriptionRepository.healthCheckHandler = { () async throws -> Bool in true }

        let response = DomainTranscriptionResponse(
            text: "Raw transcript",
            language: "en",
            durationSeconds: 1.0,
            model: "test-model",
            processedAt: "now"
        )
        transcriptionRepository.transcribeHandler = { _, _ in response }

        let prompt = DomainPostProcessingPrompt(title: "Summarize", content: "Summarize this")
        postProcessingRepository.processTranscription_2Handler = { _, _ in "Processed transcript" }

        storageRepository.saveTranscriptionHandler = { _ in }

        let useCase = TranscribeAudioUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionStorageRepository: storageRepository,
            postProcessingRepository: postProcessingRepository
        )

        let meeting = MeetingEntity(app: .googleMeet)
        let audioURL = URL(fileURLWithPath: "/tmp/test.wav")

        let transcription = try await useCase.execute(
            audioURL: audioURL,
            meeting: meeting,
            applyPostProcessing: true,
            postProcessingPrompt: prompt
        )

        XCTAssertEqual(transcription.text, "Processed transcript")
        XCTAssertEqual(postProcessingRepository.processTranscriptionCalls.count, 0)
        XCTAssertEqual(postProcessingRepository.processTranscription_2Calls.count, 1)
        XCTAssertEqual(postProcessingRepository.processTranscription_2Calls.first?.prompt.id, prompt.id)
    }

    func testExecuteWithContext_MetadataIsWrappedInDedicatedBlock() async throws {
        let transcriptionRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionRepository()
        let storageRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionStorageRepository()
        let postProcessingRepository = MeetingAssistantCoreDomain.MacroMockPostProcessingRepository()

        transcriptionRepository.healthCheckHandler = { () async throws -> Bool in true }
        transcriptionRepository.transcribeHandler = { _, _ in
            DomainTranscriptionResponse(
                text: "Base transcript",
                language: "en",
                durationSeconds: 1.0,
                model: "test-model",
                processedAt: "now"
            )
        }

        var receivedInput: String?
        postProcessingRepository.processTranscription_2Handler = { input, _ in
            receivedInput = input
            return "Processed transcript"
        }
        storageRepository.saveTranscriptionHandler = { _ in }

        let useCase = TranscribeAudioUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionStorageRepository: storageRepository,
            postProcessingRepository: postProcessingRepository
        )

        let meeting = MeetingEntity(app: .googleMeet)
        let audioURL = URL(fileURLWithPath: "/tmp/test.wav")
        let prompt = DomainPostProcessingPrompt(title: "Summarize", content: "Summarize this")

        _ = try await useCase.execute(
            audioURL: audioURL,
            meeting: meeting,
            applyPostProcessing: true,
            postProcessingPrompt: prompt,
            postProcessingContext: "CONTEXT_METADATA\n- Active app: Safari"
        )

        let input = try XCTUnwrap(receivedInput)
        XCTAssertTrue(input.contains("<CONTEXT_METADATA>"))
        XCTAssertTrue(input.contains("</CONTEXT_METADATA>"))
        XCTAssertTrue(input.contains("- Active app: Safari"))
    }
}
