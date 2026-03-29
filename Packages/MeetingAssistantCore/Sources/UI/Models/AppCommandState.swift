import MeetingAssistantCoreInfrastructure

public struct AppCommandState: Equatable, Sendable {
    public var recordingSection: MenuBarRecordingSectionState
    public var cancelRecordingShortcutDefinition: ShortcutDefinition?

    public init(
        recordingSection: MenuBarRecordingSectionState = .idle,
        cancelRecordingShortcutDefinition: ShortcutDefinition? = nil
    ) {
        self.recordingSection = recordingSection
        self.cancelRecordingShortcutDefinition = cancelRecordingShortcutDefinition
    }

    public var dictationTitleKey: String {
        recordingSection == .dictationActive ? "menubar.stop_dictation" : "menubar.dictate"
    }

    public var meetingTitleKey: String {
        recordingSection == .meetingActive ? "menubar.stop_recording" : "menubar.record_meeting"
    }

    public var assistantTitleKey: String {
        recordingSection == .assistantActive ? "menubar.stop_assistant" : "menubar.assistant"
    }

    public var cancelTitleKey: String {
        "menubar.cancel_recording"
    }

    public var showsDictationAction: Bool {
        recordingSection == .idle || recordingSection == .dictationActive
    }

    public var showsMeetingAction: Bool {
        recordingSection == .idle || recordingSection == .meetingActive
    }

    public var showsAssistantAction: Bool {
        recordingSection == .idle || recordingSection == .assistantActive
    }

    public var showsCancelAction: Bool {
        recordingSection != .idle
    }
}
