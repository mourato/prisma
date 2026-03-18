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

    func testMeetingProcessingClusterReservesProgressWidth() {
        let size: FloatingRecordingIndicatorView.IndicatorSize = .classic
        let processingRenderState = RecordingIndicatorRenderState(mode: .processing, kind: .meeting)
        let processingWithoutMeetingFeedback = RecordingIndicatorRenderState(mode: .processing, kind: .dictation)

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
            renderState: processingWithoutMeetingFeedback,
            layout: layout,
            expanded: false
        )

        let expectedDelta = FloatingRecordingIndicatorViewUtilities.contentSpacing(for: size)
            + FloatingRecordingIndicatorViewUtilities.processingProgressReservedWidth(for: size)

        XCTAssertEqual(processingWidth - baseProcessingWidth, expectedDelta, accuracy: 0.001)
    }

    func testMeetingProcessingProgressVisibility_IsLimitedToMeetingProcessing() {
        XCTAssertTrue(
            FloatingRecordingIndicatorViewUtilities.shouldShowMeetingProcessingProgress(
                renderState: RecordingIndicatorRenderState(mode: .processing, kind: .meeting)
            )
        )
        XCTAssertFalse(
            FloatingRecordingIndicatorViewUtilities.shouldShowMeetingProcessingProgress(
                renderState: RecordingIndicatorRenderState(mode: .recording, kind: .meeting)
            )
        )
        XCTAssertFalse(
            FloatingRecordingIndicatorViewUtilities.shouldShowMeetingProcessingProgress(
                renderState: RecordingIndicatorRenderState(mode: .processing, kind: .dictation)
            )
        )
        XCTAssertFalse(
            FloatingRecordingIndicatorViewUtilities.shouldShowMeetingProcessingProgress(
                renderState: RecordingIndicatorRenderState(mode: .processing, kind: .assistant)
            )
        )
    }
}
