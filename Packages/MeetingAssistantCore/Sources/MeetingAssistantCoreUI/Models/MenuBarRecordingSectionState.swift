import MeetingAssistantCoreDomain

public enum MenuBarRecordingSectionState: Equatable {
    case idle
    case dictationActive
    case meetingActive
    case assistantActive

    public init(
        isRecordingManagerActive: Bool,
        recordingSource: RecordingSource,
        isAssistantRecording: Bool
    ) {
        if isAssistantRecording {
            self = .assistantActive
            return
        }

        guard isRecordingManagerActive else {
            self = .idle
            return
        }

        switch recordingSource {
        case .microphone:
            self = .dictationActive
        case .system, .all:
            self = .meetingActive
        }
    }
}
