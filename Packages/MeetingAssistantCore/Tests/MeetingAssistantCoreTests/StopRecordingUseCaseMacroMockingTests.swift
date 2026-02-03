import Foundation
@testable import MeetingAssistantCore
import XCTest

final class StopRecordingUseCaseMacroMockingTests: XCTestCase {
    func testExecuteSuccess_StopsRecordingAndUpdatesMeeting() async throws {
        let recordingRepository = MeetingAssistantCore.MacroMockRecordingRepository()
        let meetingRepository = MeetingAssistantCore.MacroMockMeetingRepository()

        let expectedURL = URL(fileURLWithPath: "/tmp/test.wav")
        recordingRepository.stopRecordingHandler = { () async throws -> URL? in expectedURL }
        meetingRepository.updateMeetingHandler = { _ in }

        let useCase = StopRecordingUseCase(
            recordingRepository: recordingRepository,
            meetingRepository: meetingRepository
        )

        let meeting = MeetingEntity(app: .googleMeet)
        let result = try await useCase.execute(for: meeting)

        XCTAssertEqual(result, expectedURL)
        XCTAssertEqual(recordingRepository.stopRecordingCallCount, 1)
        XCTAssertEqual(meetingRepository.updateMeetingCalls.count, 1)
        XCTAssertNotNil(meetingRepository.updateMeetingCalls.first?.meeting.endTime)
    }
}
