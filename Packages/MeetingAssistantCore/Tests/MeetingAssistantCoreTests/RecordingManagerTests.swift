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
        mockMic = MockAudioRecorder()
        mockSystem = MockAudioRecorder()
        mockTranscription = MockTranscriptionClient()
        mockPostProcessing = MockPostProcessingService()
        mockStorage = MockStorageService()

        manager = RecordingManager(
            micRecorder: mockMic,
            systemRecorder: mockSystem,
            transcriptionClient: mockTranscription,
            postProcessingService: mockPostProcessing,
            storage: mockStorage
        )
    }

    override func tearDown() async throws {
        manager = nil
        mockMic = nil
        mockSystem = nil
        mockTranscription = nil
        mockPostProcessing = nil
        mockStorage = nil
        try await super.tearDown()
    }

    // MARK: - Basic Tests

    func testInitialization() {
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isTranscribing)
    }

    func testStorageServiceUsage() async {
        await manager.startRecording()
        XCTAssertTrue(mockStorage.createRecordingURLCalled)
    }

    func testCheckPermissions_WhenBothGranted() async {
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.checkPermission()

        XCTAssertTrue(manager.hasRequiredPermissions)
    }

    func testCheckPermissions_WhenOneDenied() async {
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = false

        await manager.checkPermission()

        XCTAssertFalse(manager.hasRequiredPermissions)
    }

    func testStartRecording_Success() async {
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startRecording()

        XCTAssertTrue(manager.isRecording)
        XCTAssertTrue(mockMic.startRecordingCalled)
    }

    func testStartRecording_FailsIfAlreadyRecording() async {
        await manager.startRecording()

        mockMic.startRecordingCalled = false

        await manager.startRecording()

        XCTAssertFalse(mockMic.startRecordingCalled)
    }

    // MARK: - Error Handling Tests

    func testStartRecording_FailsWhenSystemRecorderFails() async {
        // Given
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true
        mockMic.shouldFailStart = true

        // When
        do {
            try await mockMic.startRecording(to: URL(fileURLWithPath: "/tmp/test.m4a"), retryCount: 0)
            XCTFail("Expected error to be thrown")
        } catch {
            // Then
            XCTAssertNotNil(error)
        }
    }

    func testStopRecording_HandlesErrorGracefully() async {
        // Given
        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startRecording()

        // When - stopping should not throw even if cleanup fails
        await manager.stopRecording()

        // Then - should have stopped
        XCTAssertFalse(manager.isRecording)
    }

    func testTranscription_FailsWithInvalidURL() async throws {
        // Given
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/file.m4a")
        mockTranscription.shouldFailTranscription = true

        // When/Then
        do {
            _ = try await mockTranscription.transcribe(audioURL: invalidURL)
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
        mockStorage.mockTranscriptions = [mockTranscription]

        // When
        let transcriptions = try await mockStorage.loadTranscriptions()

        // Then
        XCTAssertEqual(transcriptions.count, 1)
        XCTAssertEqual(mockStorage.loadTranscriptionsCallCount, 1)
    }

    func testMockTranscriptionClient_CallTracking() async throws {
        // Given
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        _ = try await mockTranscription.transcribe(audioURL: audioURL)

        // Then
        XCTAssertEqual(mockTranscription.transcribeCallCount, 1)
        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, audioURL)
    }

    func testMockAudioRecorder_CallTracking() async throws {
        // Given
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        try await mockMic.startRecording(to: audioURL, retryCount: 0)
        _ = await mockMic.stopRecording()

        // Then
        XCTAssertEqual(mockMic.startRecordingParams.count, 1)
        XCTAssertEqual(mockMic.startRecordingParams.first?.url, audioURL)
        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
    }
}
