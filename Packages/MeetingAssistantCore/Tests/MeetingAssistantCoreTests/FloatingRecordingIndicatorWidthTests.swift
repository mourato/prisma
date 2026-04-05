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

    func testSuperWaveCount_IsEighty() {
        XCTAssertEqual(
            FloatingRecordingIndicatorViewUtilities.waveCount(for: .`super`),
            AppDesignSystem.Layout.recordingIndicatorSuperWaveCount
        )
    }

    func testSuperWaveformWidth_UsesCompressedMetrics() {
        let expectedWidth =
            (CGFloat(AppDesignSystem.Layout.recordingIndicatorSuperWaveCount)
                * AppDesignSystem.Layout.recordingIndicatorSuperWaveformBarWidth)
            + (CGFloat(AppDesignSystem.Layout.recordingIndicatorSuperWaveCount - 1)
                * AppDesignSystem.Layout.recordingIndicatorSuperWaveformBarSpacing)

        let actualWidth = FloatingRecordingIndicatorViewUtilities.waveformWidth(for: .`super`)

        XCTAssertEqual(actualWidth, expectedWidth, accuracy: 0.001)
        XCTAssertLessThan(actualWidth, 225)
    }

    func testSuperPanelWidth_UsesIntegratedFooterLayout() {
        let settings = AppSettingsStore.shared
        let controller = FloatingRecordingIndicatorController(settingsStore: settings)
        let renderState = RecordingIndicatorRenderState(mode: .recording, kind: .dictation)
        let layout = RecordingIndicatorOverlayLayout.resolve(renderState: renderState, settingsStore: settings)

        let panelWidth = controller.panelWidthForTesting(style: .`super`, renderState: renderState)
        let expectedWidth = FloatingRecordingIndicatorViewUtilities.superCardWidth(
            layout: layout,
            renderState: renderState
        )

        XCTAssertEqual(panelWidth, expectedWidth, accuracy: 0.001)
    }

    func testSuperPanelHeight_IncludesFooterDuringRecording() {
        let settings = AppSettingsStore.shared
        let controller = FloatingRecordingIndicatorController(settingsStore: settings)
        let renderState = RecordingIndicatorRenderState(mode: .recording, kind: .meeting)
        let layout = RecordingIndicatorOverlayLayout.resolve(renderState: renderState, settingsStore: settings)

        let panelHeight = controller.panelHeightForTesting(style: .`super`, renderState: renderState)
        let expectedHeight = FloatingRecordingIndicatorViewUtilities.superCardHeight(
            layout: layout,
            renderState: renderState
        )

        XCTAssertEqual(panelHeight, expectedHeight, accuracy: 0.001)
        XCTAssertGreaterThan(panelHeight, AppDesignSystem.Layout.recordingIndicatorClassicHeight)
    }
}
