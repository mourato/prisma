import MeetingAssistantCoreDomain

public enum RecordingIndicatorKind: Sendable, Equatable {
    case dictation
    case meeting
}

public struct RecordingIndicatorRenderState: Sendable, Equatable {
    public let mode: FloatingRecordingIndicatorMode
    public let kind: RecordingIndicatorKind
    public let meetingType: MeetingType?

    public init(
        mode: FloatingRecordingIndicatorMode,
        kind: RecordingIndicatorKind,
        meetingType: MeetingType? = nil
    ) {
        self.mode = mode
        self.kind = kind
        self.meetingType = meetingType
    }

    public func with(mode: FloatingRecordingIndicatorMode) -> RecordingIndicatorRenderState {
        RecordingIndicatorRenderState(mode: mode, kind: kind, meetingType: meetingType)
    }

    public static func fromLegacy(mode: FloatingRecordingIndicatorMode, meetingType: MeetingType?) -> RecordingIndicatorRenderState {
        let kind: RecordingIndicatorKind = meetingType == nil ? .dictation : .meeting
        return RecordingIndicatorRenderState(mode: mode, kind: kind, meetingType: meetingType)
    }
}
