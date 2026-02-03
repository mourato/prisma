import Foundation

public enum AppNotifications {
    public enum UserInfoKey {
        public static let transcriptionId = "transcriptionId"
    }
}

public extension Notification.Name {
    static let meetingAssistantTranscriptionSaved = Notification.Name("meetingAssistant.transcription.saved")
}
