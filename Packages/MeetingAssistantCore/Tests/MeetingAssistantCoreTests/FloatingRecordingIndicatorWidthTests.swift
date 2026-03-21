@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class FloatingRecordingIndicatorWidthTests: XCTestCase {
    func testMeetingTimerDividerWidthContributionMatchesLayoutBudget() {
        let size: FloatingRecordingIndicatorView.IndicatorSize = .classic
        let renderState = RecordingIndicatorRenderState(mode: .recording, kind: .meeting)
        let layoutWithoutTimer = RecordingIndicatorOverlayLayout(
            showsPromptSelector: false,
            showsLanguageSelector: false,
            showsMeetingTimer: false
        )
        let layoutWithTimer = RecordingIndicatorOverlayLayout(
            showsPromptSelector: false,
            showsLanguageSelector: false,
            showsMeetingTimer: true
        )

        let widthWithoutTimer = FloatingRecordingIndicatorViewUtilities.mainPillWidth(
            for: size,
            renderState: renderState,
            layout: layoutWithoutTimer,
            expanded: false
        )
        let widthWithTimer = FloatingRecordingIndicatorViewUtilities.mainPillWidth(
            for: size,
            renderState: renderState,
            layout: layoutWithTimer,
            expanded: false
        )

        let expectedDelta = FloatingRecordingIndicatorViewUtilities.dividerWidth
            + FloatingRecordingIndicatorViewUtilities.timerReservedWidth(for: size)
            + (FloatingRecordingIndicatorViewUtilities.contentSpacing(for: size) * 2)

        XCTAssertEqual(widthWithTimer - widthWithoutTimer, expectedDelta, accuracy: 0.001)
    }

    func testProcessingClusterWidth_IsIndependentFromRecordingKind() {
        let size: FloatingRecordingIndicatorView.IndicatorSize = .classic
        let processingRenderState = RecordingIndicatorRenderState(mode: .processing, kind: .meeting)
        let dictationProcessingState = RecordingIndicatorRenderState(mode: .processing, kind: .dictation)

        let layout = RecordingIndicatorOverlayLayout(
            showsPromptSelector: false,
            showsLanguageSelector: false,
            showsMeetingTimer: false
        )

        let processingWidth = FloatingRecordingIndicatorViewUtilities.mainPillWidth(
            for: size,
            renderState: processingRenderState,
            layout: layout,
            expanded: false
        )
        let baseProcessingWidth = FloatingRecordingIndicatorViewUtilities.mainPillWidth(
            for: size,
            renderState: dictationProcessingState,
            layout: layout,
            expanded: false
        )

        XCTAssertEqual(processingWidth, baseProcessingWidth, accuracy: 0.001)
    }

    func testProcessingClusterUsesStatusWidthInsteadOfWaveform() {
        let size: FloatingRecordingIndicatorView.IndicatorSize = .classic
        let processingState = RecordingIndicatorRenderState(mode: .processing, kind: .assistant)

        let expectedClusterWidth = AppDesignSystem.Layout.recordingIndicatorDotSize
            + FloatingRecordingIndicatorViewUtilities.processingProgressReservedWidth(for: size)
            + FloatingRecordingIndicatorViewUtilities.contentSpacing(for: size)

        let actualClusterWidth = FloatingRecordingIndicatorViewUtilities.clusterWidth(
            for: size,
            renderState: processingState
        )

        XCTAssertEqual(actualClusterWidth, expectedClusterWidth, accuracy: 0.001)
    }

    func testMainContentMode_UsesWaveformDuringRecordingAndStatusDuringProcessing() {
        XCTAssertTrue(
            FloatingRecordingIndicatorViewUtilities.mainContentMode(
                for: RecordingIndicatorRenderState(mode: .recording, kind: .meeting)
            ) == .waveform
        )
        XCTAssertTrue(
            FloatingRecordingIndicatorViewUtilities.mainContentMode(
                for: RecordingIndicatorRenderState(mode: .starting, kind: .dictation)
            ) == .waveform
        )
        XCTAssertTrue(
            FloatingRecordingIndicatorViewUtilities.mainContentMode(
                for: RecordingIndicatorRenderState(mode: .processing, kind: .meeting)
            ) == .processingStatus
        )
    }
}
