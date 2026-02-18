import XCTest
@testable import MeetingAssistantCore

final class RecordingIndicatorRenderStateTests: XCTestCase {
    func testFromLegacy_WithoutMeetingType_CreatesDictationKind() {
        let state = RecordingIndicatorRenderState.fromLegacy(mode: .recording, meetingType: nil)

        XCTAssertEqual(state.mode, .recording)
        XCTAssertEqual(state.kind, .dictation)
        XCTAssertNil(state.meetingType)
    }

    func testFromLegacy_WithMeetingType_CreatesMeetingKind() {
        let state = RecordingIndicatorRenderState.fromLegacy(mode: .processing, meetingType: .standup)

        XCTAssertEqual(state.mode, .processing)
        XCTAssertEqual(state.kind, .meeting)
        XCTAssertEqual(state.meetingType, .standup)
    }

    func testWithMode_PreservesKindAndMeetingType() {
        let initial = RecordingIndicatorRenderState(mode: .starting, kind: .meeting, meetingType: .planning)

        let updated = initial.with(mode: .recording)

        XCTAssertEqual(updated.mode, .recording)
        XCTAssertEqual(updated.kind, .meeting)
        XCTAssertEqual(updated.meetingType, .planning)
    }
}
