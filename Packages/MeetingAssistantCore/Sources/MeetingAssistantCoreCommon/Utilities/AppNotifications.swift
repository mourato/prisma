import Foundation

public enum AppNotifications {
    public enum UserInfoKey {
        public static let transcriptionId = "transcriptionId"
        public static let shortcutCaptureHealthStatus = "shortcutCaptureHealthStatus"
        public static let meetingNoteMeetingID = "meetingNoteMeetingID"
        public static let meetingNoteMarkdown = "meetingNoteMarkdown"
        public static let meetingNoteUpdatedAtMillis = "meetingNoteUpdatedAtMillis"
    }
}

public extension Notification.Name {
    static let meetingAssistantTranscriptionSaved = Notification.Name("meetingAssistant.transcription.saved")
    static let meetingAssistantShortcutCaptureHealthDidChange = Notification.Name("meetingAssistant.shortcutCaptureHealth.didChange")
    static let meetingAssistantMeetingNoteDidSave = Notification.Name("meetingAssistant.meetingNote.didSave")
}
