import Combine
@testable import MeetingAssistantCore
import XCTest

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
        XCTAssertNil(viewModel.statusText)
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
        XCTAssertEqual(viewModel.statusText, "status.recording".localized)
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
        XCTAssertEqual(viewModel.statusText, "status.transcribing".localized)
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
                == mockService.transcriptionStatus.statusMessage
        )
    }

    // MARK: - Performance Tests

    func testPerformance_StartRecordingOperation() throws {
        try XCTSkipIf(true, "Flaky performance test - Race condition in measure block")
        // Baseline: UI operations should be fast
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            Task {
                await viewModel.startRecording()
            }
        }

        XCTAssertTrue(mockService.startRecordingCalled)
    }

    func testPerformance_StopRecordingOperation() async throws {
        try XCTSkipIf(true, "Flaky performance test - Race condition in measure block")
        // Pre-start recording
        await viewModel.startRecording()
        mockService.startRecordingCalled = false // Reset for measurement

        // Baseline: Stop operations should be fast
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            Task {
                await viewModel.stopRecording()
            }
        }

        XCTAssertTrue(mockService.stopRecordingCalled)
    }

    func testPerformance_StatusTextComputation() throws {
        try XCTSkipIf(true, "Flaky performance test")
        // Baseline: Status text computation should be very fast
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<1_000 {
                _ = viewModel.statusText
            }
        }
    }

    func testPerformance_StateUpdates() throws {
        try XCTSkipIf(true, "Flaky performance test")
        // Baseline: State updates through Combine should be efficient
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            Task {
                for _ in 0..<100 {
                    mockService.simulateState(recording: true, transcribing: false)
                    mockService.simulateState(recording: false, transcribing: true)
                    mockService.simulateState(recording: false, transcribing: false)
                }
            }
        }
    }
}
