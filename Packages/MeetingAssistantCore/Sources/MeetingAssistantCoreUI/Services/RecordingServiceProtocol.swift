import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Protocol defining the public interface of the recording orchestration service.
@MainActor
public protocol RecordingServiceProtocol: AnyObject {
    // Properties
    var meetingState: MeetingState { get }
    var isRecording: Bool { get }
    var isTranscribing: Bool { get }
    var currentMeeting: Meeting? { get }
    var transcriptionStatus: TranscriptionStatus { get }
    var permissionStatus: PermissionStatusManager { get }

    // Publishers
    var meetingStatePublisher: AnyPublisher<MeetingState, Never> { get }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    var isTranscribingPublisher: AnyPublisher<Bool, Never> { get }
    var currentMeetingPublisher: AnyPublisher<Meeting?, Never> { get }

    // Actions
    func startRecording(source: RecordingSource) async
    func stopRecording() async
    func transcribeExternalAudio(from audioURL: URL) async
    func checkPermission() async
    func checkPermission(for source: RecordingSource) async
    func requestPermission() async
    func requestPermission(for source: RecordingSource) async
    func openMicrophoneSettings()
    func openPermissionSettings()
    func requestAccessibilityPermission()
    func openAccessibilitySettings()
}
