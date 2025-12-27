import XCTest
import Combine
@testable import MeetingAssistantCore

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
        
        // Ensure meeting detector is not forcing anything weird
        // We rely on dependencies.
        
        await manager.startRecording()
        
        XCTAssertTrue(manager.isRecording)
        XCTAssertTrue(mockMic.startRecordingCalled)
        // System audio recorder is called asynchronously in manager?
        // Let's check logic: "try await systemRecorder.startRecording" is awaited.
        // But logic showed:
        // try await micRecorder.startRecording...
        // try await systemRecorder.startRecording...
        // So it should be sequential and awaited.
        
        XCTAssertTrue(mockSystem.startRecordingCalled)
    }
    
    func testStartRecording_FailsIfAlreadyRecording() async {
        // Force state
        await manager.startRecording() // First start
        
        mockMic.startRecordingCalled = false
        
        await manager.startRecording() // Second start
        
        XCTAssertFalse(mockMic.startRecordingCalled, "Should not start again if already recording")
    }
}
