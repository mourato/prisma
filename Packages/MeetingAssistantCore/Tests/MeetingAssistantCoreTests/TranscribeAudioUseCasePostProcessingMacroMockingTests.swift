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
        postProcessingRepository.processTranscriptionStructured_2Handler = { _, _ in
            DomainPostProcessingResult(
                processedText: "Processed transcript",
                canonicalSummary: CanonicalSummary(
                    summary: "Processed transcript",
                    trustFlags: .init(
                        isGroundedInTranscript: true,
                        containsSpeculation: false,
                        isHumanReviewed: false,
                        confidenceScore: 0.9
                    )
                ),
                outputState: .structured
            )
        }

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
        XCTAssertEqual(transcription.canonicalSummary?.summary, "Processed transcript")
        XCTAssertNotNil(transcription.qualityProfile)
        XCTAssertEqual(postProcessingRepository.processTranscriptionCalls.count, 0)
        XCTAssertEqual(postProcessingRepository.processTranscription_2Calls.count, 0)
        XCTAssertEqual(postProcessingRepository.processTranscriptionStructured_2Calls.count, 1)
        XCTAssertEqual(postProcessingRepository.processTranscriptionStructured_2Calls.first?.prompt.id, prompt.id)
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
        postProcessingRepository.processTranscriptionStructured_2Handler = { input, _ in
            receivedInput = input
            return DomainPostProcessingResult(
                processedText: "Processed transcript",
                canonicalSummary: CanonicalSummary(
                    summary: "Processed transcript",
                    trustFlags: .init(
                        isGroundedInTranscript: true,
                        containsSpeculation: false,
                        isHumanReviewed: false,
                        confidenceScore: 0.9
                    )
                ),
                outputState: .structured
            )
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
        XCTAssertTrue(input.contains("<TRANSCRIPT_QUALITY>"))
        XCTAssertTrue(input.contains("</TRANSCRIPT_QUALITY>"))
        XCTAssertTrue(input.contains("<CONTEXT_METADATA>"))
        XCTAssertTrue(input.contains("</CONTEXT_METADATA>"))
        XCTAssertTrue(input.contains("- Active app: Safari"))
    }

    func testExecuteWithDeterministicFallback_PersistsCanonicalSummaryTrustFlags() async throws {
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

        let prompt = DomainPostProcessingPrompt(title: "Summarize", content: "Summarize this")
        postProcessingRepository.processTranscriptionStructured_2Handler = { _, _ in
            DomainPostProcessingResult(
                processedText: "Fallback summary",
                canonicalSummary: CanonicalSummary(
                    summary: "Fallback summary",
                    trustFlags: .init(
                        isGroundedInTranscript: false,
                        containsSpeculation: true,
                        isHumanReviewed: false,
                        confidenceScore: 0.2
                    )
                ),
                outputState: .deterministicFallback
            )
        }
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

        XCTAssertEqual(transcription.canonicalSummary?.summary, "Fallback summary")
        XCTAssertEqual(transcription.canonicalSummary?.trustFlags.containsSpeculation, true)
        XCTAssertEqual(transcription.canonicalSummary?.trustFlags.confidenceScore ?? -1, 0.2, accuracy: 0.001)
    }

    func testExecute_AppliesVocabularyReplacementsBeforePostProcessing() async throws {
        let transcriptionRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionRepository()
        let storageRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionStorageRepository()
        let postProcessingRepository = MeetingAssistantCoreDomain.MacroMockPostProcessingRepository()

        transcriptionRepository.healthCheckHandler = { () async throws -> Bool in true }
        transcriptionRepository.transcribeHandler = { _, _ in
            DomainTranscriptionResponse(
                text: "open ay eye shipped it",
                language: "en",
                durationSeconds: 1.0,
                model: "test-model",
                processedAt: "now"
            )
        }

        var receivedInput: String?
        postProcessingRepository.processTranscriptionStructured_2Handler = { input, _ in
            receivedInput = input
            return DomainPostProcessingResult(
                processedText: "Processed transcript",
                canonicalSummary: CanonicalSummary(
                    summary: "Processed transcript",
                    trustFlags: .init(
                        isGroundedInTranscript: true,
                        containsSpeculation: false,
                        isHumanReviewed: false,
                        confidenceScore: 0.9
                    )
                ),
                outputState: .structured
            )
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
            vocabularyReplacementRules: [
                VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI"),
            ],
            applyPostProcessing: true,
            postProcessingPrompt: prompt
        )

        let input = try XCTUnwrap(receivedInput)
        XCTAssertTrue(input.contains("OpenAI shipped it"))
        XCTAssertTrue(input.contains("<TRANSCRIPT_QUALITY>"))
    }

    func testExecute_AppliesVocabularyReplacementsWithoutChangingRawText() async throws {
        let transcriptionRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionRepository()
        let storageRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionStorageRepository()

        transcriptionRepository.healthCheckHandler = { () async throws -> Bool in true }
        transcriptionRepository.transcribeHandler = { _, _ in
            DomainTranscriptionResponse(
                text: "OPEN AY EYE updates",
                segments: [
                    DomainTranscriptionSegment(
                        speaker: "Speaker 1",
                        text: "open ay eye status",
                        startTime: 0,
                        endTime: 1
                    ),
                ],
                language: "en",
                durationSeconds: 1.0,
                model: "test-model",
                processedAt: "now"
            )
        }

        storageRepository.saveTranscriptionHandler = { _ in }

        let useCase = TranscribeAudioUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionStorageRepository: storageRepository,
            postProcessingRepository: nil
        )

        let meeting = MeetingEntity(app: .googleMeet)
        let audioURL = URL(fileURLWithPath: "/tmp/test.wav")

        let transcription = try await useCase.execute(
            audioURL: audioURL,
            meeting: meeting,
            vocabularyReplacementRules: [
                VocabularyReplacementRule(find: "open ay eye", replace: "OpenAI"),
            ],
            applyPostProcessing: false
        )

        XCTAssertEqual(transcription.text, "OpenAI updates")
        XCTAssertEqual(transcription.rawText, "OPEN AY EYE updates")
        XCTAssertEqual(transcription.segments.first?.text, "OpenAI status")
    }
}
