import AVFoundation
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class IncrementalMeetingTranscriptionCoordinatorTests: XCTestCase {
    func testFinish_WithFinalDiarizationAssignsSpeakersAndPersistsFinalizingCheckpoint() async throws {
        let storage = MockStorageService()
        let transcriptionClient = MockTranscriptionClient()
        transcriptionClient.mockText = "meeting partial"
        transcriptionClient.mockSegments = [
            Transcription.Segment(
                speaker: Transcription.unknownSpeaker,
                text: "meeting partial",
                startTime: 0,
                endTime: 1.0
            ),
        ]
        transcriptionClient.mockSpeakerTimeline = [
            SpeakerTimelineSegment(
                speaker: "Speaker 1",
                startTime: 0,
                endTime: 10.0
            ),
        ]

        let processedDurationRecorder = ProcessedDurationRecorder()
        let coordinator = IncrementalMeetingTranscriptionCoordinator(
            transcriptionID: UUID(),
            meeting: makeMeeting(),
            inputSource: "system+microphone",
            storage: storage,
            transcriptionClient: transcriptionClient,
            callbacks: .init(
                onProcessedDurationChanged: { processedDurationRecorder.values.append($0) }
            )
        )

        try await coordinator.start()
        await coordinator.append(buffer: try makeBuffer(segments: [.tone(1.0, amplitude: 0.25)]))

        let result = try await coordinator.finish(
            audioURL: URL(fileURLWithPath: "/tmp/meeting-test.wav"),
            diarizationEnabled: true,
            finalDiarizationService: transcriptionClient
        )

        XCTAssertEqual(transcriptionClient.fileTranscribeCallCount, 0)
        XCTAssertEqual(transcriptionClient.sampleTranscribeCallCount, 1)
        XCTAssertEqual(transcriptionClient.diarizeCallCount, 1)
        XCTAssertEqual(transcriptionClient.assignSpeakersCallCount, 1)
        XCTAssertEqual(storage.savedTranscriptions.first?.lifecycleState, .partial)
        XCTAssertEqual(storage.savedTranscriptions.last?.lifecycleState, .finalizing)
        XCTAssertEqual(result.checkpointID, coordinator.checkpointID)
        XCTAssertEqual(result.response.segments.map(\.speaker), ["Speaker 1"])
        XCTAssertEqual(result.response.text, "meeting partial")
        XCTAssertFalse(processedDurationRecorder.values.isEmpty)
    }

    func testFinish_WhenWindowTranscriptionFailsMarksFallbackAndPersistsFailedCheckpoint() async throws {
        let storage = MockStorageService()
        let transcriptionClient = MockTranscriptionClient()
        transcriptionClient.shouldFailTranscription = true
        let coordinator = IncrementalMeetingTranscriptionCoordinator(
            transcriptionID: UUID(),
            meeting: makeMeeting(),
            inputSource: "system+microphone",
            storage: storage,
            transcriptionClient: transcriptionClient,
            callbacks: .init(
                onProcessedDurationChanged: { _ in }
            )
        )

        try await coordinator.start()
        await coordinator.append(buffer: try makeBuffer(segments: [.tone(1.0, amplitude: 0.25)]))

        do {
            _ = try await coordinator.finish(
                audioURL: URL(fileURLWithPath: "/tmp/meeting-test.wav"),
                diarizationEnabled: true,
                finalDiarizationService: transcriptionClient
            )
            XCTFail("Expected finish to throw")
        } catch {}

        XCTAssertTrue(coordinator.requiresLegacyFallback)
        XCTAssertNotNil(coordinator.fallbackError)
        XCTAssertEqual(storage.savedTranscriptions.last?.lifecycleState, .failed)
    }

    func testFinish_WhenNoIncrementalTranscriptIsProduced_MarksFallbackAndThrows() async throws {
        let storage = MockStorageService()
        let transcriptionClient = MockTranscriptionClient()
        let coordinator = IncrementalMeetingTranscriptionCoordinator(
            transcriptionID: UUID(),
            meeting: makeMeeting(),
            inputSource: "system+microphone",
            storage: storage,
            transcriptionClient: transcriptionClient,
            callbacks: .init(
                onProcessedDurationChanged: { _ in }
            )
        )

        try await coordinator.start()

        do {
            _ = try await coordinator.finish(
                audioURL: URL(fileURLWithPath: "/tmp/meeting-test.wav"),
                diarizationEnabled: true,
                finalDiarizationService: transcriptionClient
            )
            XCTFail("Expected finish to throw")
        } catch let error as TranscriptionError {
            guard case let .transcriptionFailed(message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(message, PostProcessingError.emptyTranscription.localizedDescription)
        }

        XCTAssertTrue(coordinator.requiresLegacyFallback)
        XCTAssertNotNil(coordinator.fallbackError)
        XCTAssertEqual(storage.savedTranscriptions.last?.lifecycleState, .failed)
        XCTAssertEqual(transcriptionClient.fileTranscribeCallCount, 0)
        XCTAssertEqual(transcriptionClient.sampleTranscribeCallCount, 0)
    }

    private func makeMeeting() -> Meeting {
        Meeting(
            app: .unknown,
            capturePurpose: .meeting,
            title: "Meeting Test",
            audioFilePath: "/tmp/meeting-test.wav"
        )
    }

    private func makeBuffer(segments: [CoordinatorSampleSegment], sampleRate: Double = 16_000) throws -> AVAudioPCMBuffer {
        let samples = segments.flatMap { segment in
            let sampleCount = Int(segment.duration * sampleRate)
            return (0..<sampleCount).map { frameIndex in
                segment.sample(at: frameIndex, sampleRate: sampleRate)
            }
        }

        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let frameCount = AVAudioFrameCount(samples.count)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "IncrementalMeetingTranscriptionCoordinatorTests", code: 1)
        }

        for (index, sample) in samples.enumerated() {
            channelData[0][index] = sample
        }

        return buffer
    }
}

private struct CoordinatorSampleSegment {
    let duration: Double
    let amplitude: Float

    static func tone(_ duration: Double, amplitude: Float) -> CoordinatorSampleSegment {
        CoordinatorSampleSegment(duration: duration, amplitude: amplitude)
    }

    func sample(at frameIndex: Int, sampleRate: Double) -> Float {
        let angle = 2 * Double.pi * Double(frameIndex) * 220 / sampleRate
        return sin(Float(angle)) * amplitude
    }
}

private final class ProcessedDurationRecorder: @unchecked Sendable {
    var values: [Double] = []
}
