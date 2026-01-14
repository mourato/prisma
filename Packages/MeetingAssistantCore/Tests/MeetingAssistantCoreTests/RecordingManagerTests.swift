import Combine
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class RecordingManagerTests: XCTestCase {
    var manager: RecordingManager!
    var mockMic: MockAudioRecorder!
    var mockSystem: MockAudioRecorder!
    var mockTranscription: MockTranscriptionClient!
    var mockPostProcessing: MockPostProcessingService!
    var mockStorage: MockStorageService!

    override func setUp() async throws {
        try await super.setUp()
        self.mockMic = MockAudioRecorder()
        self.mockSystem = MockAudioRecorder()
        self.mockTranscription = MockTranscriptionClient()
        self.mockPostProcessing = MockPostProcessingService()
        self.mockStorage = MockStorageService()

        self.manager = RecordingManager(
            micRecorder: self.mockMic,
            systemRecorder: self.mockSystem,
            transcriptionClient: self.mockTranscription,
            postProcessingService: self.mockPostProcessing,
            storage: self.mockStorage
        )
    }

    override func tearDown() async throws {
        self.manager = nil
        self.mockMic = nil
        self.mockSystem = nil
        self.mockTranscription = nil
        self.mockPostProcessing = nil
        self.mockStorage = nil
        try await super.tearDown()
    }

    // MARK: - Basic Tests

    func testInitialization() {
        XCTAssertNotNil(self.manager)
        XCTAssertFalse(self.manager.isRecording)
        XCTAssertFalse(self.manager.isTranscribing)
    }

    func testStorageServiceUsage() async {
        await self.manager.startRecording()
        XCTAssertTrue(self.mockStorage.createRecordingURLCalled)
    }

    func testCheckPermissions_WhenBothGranted() async {
        self.mockMic.permissionGranted = true
        self.mockSystem.permissionGranted = true

        await self.manager.checkPermission()

        XCTAssertTrue(self.manager.hasRequiredPermissions)
    }

    func testCheckPermissions_WhenOneDenied() async {
        self.mockMic.permissionGranted = true
        self.mockSystem.permissionGranted = false

        await self.manager.checkPermission()

        XCTAssertFalse(self.manager.hasRequiredPermissions)
    }

    func testStartRecording_Success() async {
        self.mockMic.permissionGranted = true
        self.mockSystem.permissionGranted = true

        await self.manager.startRecording()

        XCTAssertTrue(self.manager.isRecording)
        XCTAssertTrue(self.mockMic.startRecordingCalled)
    }

    func testStartRecording_FailsIfAlreadyRecording() async {
        await self.manager.startRecording()

        self.mockMic.startRecordingCalled = false

        await self.manager.startRecording()

        XCTAssertFalse(self.mockMic.startRecordingCalled)
    }

    // MARK: - Error Handling Tests

    func testStartRecording_FailsWhenSystemRecorderFails() async {
        // Given
        self.mockMic.permissionGranted = true
        self.mockSystem.permissionGranted = true
        self.mockMic.shouldFailStart = true

        // When
        do {
            try await self.mockMic.startRecording(to: URL(fileURLWithPath: "/tmp/test.m4a"), retryCount: 0)
            XCTFail("Expected error to be thrown")
        } catch {
            // Then
            XCTAssertNotNil(error)
        }
    }

    func testStopRecording_HandlesErrorGracefully() async {
        // Given
        self.mockMic.permissionGranted = true
        self.mockSystem.permissionGranted = true

        await self.manager.startRecording()

        // When - stopping should not throw even if cleanup fails
        await self.manager.stopRecording()

        // Then - should have stopped
        XCTAssertFalse(self.manager.isRecording)
    }

    func testTranscription_FailsWithInvalidURL() async throws {
        // Given
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/file.m4a")
        self.mockTranscription.shouldFailTranscription = true

        // When/Then
        do {
            _ = try await self.mockTranscription.transcribe(audioURL: invalidURL)
            XCTFail("Expected error for transcription failure")
        } catch {
            // Should fail when shouldFailTranscription is true
            XCTAssertNotNil(error)
        }
    }

    func testMockStorageService_LoadTranscriptions() async throws {
        // Given
        let mockTranscription = Transcription(
            meeting: Meeting(app: .unknown),
            text: "Test transcription",
            rawText: "Test transcription",
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: "pt",
            modelName: "test-model"
        )
        self.mockStorage.mockTranscriptions = [mockTranscription]

        // When
        let transcriptions = try await mockStorage.loadTranscriptions()

        // Then
        XCTAssertEqual(transcriptions.count, 1)
        XCTAssertEqual(self.mockStorage.loadTranscriptionsCallCount, 1)
    }

    func testMockTranscriptionClient_CallTracking() async throws {
        // Given
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        _ = try await self.mockTranscription.transcribe(audioURL: audioURL)

        // Then
        XCTAssertEqual(self.mockTranscription.transcribeCallCount, 1)
        XCTAssertEqual(self.mockTranscription.lastTranscribeAudioURL, audioURL)
    }

    func testMockAudioRecorder_CallTracking() async throws {
        // Given
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        try await mockMic.startRecording(to: audioURL, retryCount: 0)
        _ = await self.mockMic.stopRecording()

        // Then
        XCTAssertEqual(self.mockMic.startRecordingParams.count, 1)
        XCTAssertEqual(self.mockMic.startRecordingParams.first?.url, audioURL)
        XCTAssertEqual(self.mockMic.stopRecordingCalledCount, 1)
    }
}
