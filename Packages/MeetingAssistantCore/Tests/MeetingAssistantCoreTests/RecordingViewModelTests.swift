import Combine
import XCTest

@testable import MeetingAssistantCore

@MainActor
final class RecordingViewModelTests: XCTestCase {
    var viewModel: RecordingViewModel!
    var mockService: MockRecordingService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockService = MockRecordingService()
        viewModel = RecordingViewModel(recordingManager: mockService)
        cancellables = []
    }

    override func tearDown() async throws {
        viewModel = nil
        mockService = nil
        cancellables = nil
    }

    func testInitialState() {
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isTranscribing)
        XCTAssertEqual(viewModel.statusText, "Aguardando reunião")
        XCTAssertFalse(viewModel.transcriptionViewModel.progressPercentage > 0)
    }

    func testStartRecording() async {
        await viewModel.startRecording()

        XCTAssertTrue(mockService.startRecordingCalled)

        // Simulate service update via publisher
        mockService.simulateState(recording: true, transcribing: false)

        // Wait for Combine loop
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(viewModel.statusText, "Gravando...")
    }

    func testStopRecording() async {
        // Init state
        mockService.simulateState(recording: true, transcribing: false)
        try? await Task.sleep(nanoseconds: 10_000_000)

        await viewModel.stopRecording()

        XCTAssertTrue(mockService.stopRecordingCalled)

        // Simulate transitioning to transcribing
        mockService.simulateState(recording: false, transcribing: true)
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertTrue(viewModel.isTranscribing)
        XCTAssertEqual(viewModel.statusText, "Transcrevendo...")
    }

    func testPermissionRequest() async {
        await viewModel.requestPermission()
        XCTAssertTrue(mockService.requestPermissionCalled)
    }

    func testChildViewModelInitialization() {
        XCTAssertNotNil(viewModel.transcriptionViewModel)
        // Verify it shares the same status object reference (if we exposed it, but we can verify behavior)
        // Mock service has a transcriptionStatus.
        XCTAssertTrue(
            viewModel.transcriptionViewModel.statusMessage
                == mockService.transcriptionStatus.statusMessage)
    }
}
