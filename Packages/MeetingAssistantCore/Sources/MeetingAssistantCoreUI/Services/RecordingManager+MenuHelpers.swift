import AVFoundation
import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log
import UserNotifications

// MARK: - Menu Helpers

public extension RecordingManager {
    var dictationMenuKey: String {
        (isRecording && recordingSource == .microphone) ? "menubar.stop_dictation" : "menubar.dictate"
    }

    var meetingMenuKey: String {
        (isRecording && (recordingSource == .system || recordingSource == .all)) ? "menubar.stop_recording" : "menubar.record_meeting"
    }
}
