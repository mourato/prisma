import Combine
import Foundation
@testable import MeetingAssistantCore

@MainActor
class MockRecordingService: RecordingServiceProtocol {
    // Properties
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var currentMeeting: Meeting?
    var transcriptionStatus = TranscriptionStatus()
    var permissionStatus = PermissionStatusManager()

    // Publishers
    var isRecordingSubject = PassthroughSubject<Bool, Never>()
    var isTranscribingSubject = PassthroughSubject<Bool, Never>()
    var currentMeetingSubject = PassthroughSubject<Meeting?, Never>()

    var isRecordingPublisher: AnyPublisher<Bool, Never> { self.isRecordingSubject.eraseToAnyPublisher() }
    var isTranscribingPublisher: AnyPublisher<Bool, Never> { self.isTranscribingSubject.eraseToAnyPublisher() }
    var currentMeetingPublisher: AnyPublisher<Meeting?, Never> { self.currentMeetingSubject.eraseToAnyPublisher() }

    // Track calls
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var checkPermissionCalled = false
    var requestPermissionCalled = false
    var openMicrophoneSettingsCalled = false
    var openPermissionSettingsCalled = false
    var transcribeExternalAudioCalled = false

    func startRecording(source: RecordingSource) async {
        self.startRecordingCalled = true
        self.isRecording = true
        self.isRecordingSubject.send(true)
    }

    func stopRecording() async {
        self.stopRecordingCalled = true
        self.isRecording = false
        self.isRecordingSubject.send(false)
    }

    func checkPermission() async {
        self.checkPermissionCalled = true
    }

    func requestPermission() async {
        self.requestPermissionCalled = true
    }

    func openMicrophoneSettings() {
        self.openMicrophoneSettingsCalled = true
    }

    func openPermissionSettings() {
        self.openPermissionSettingsCalled = true
    }

    func transcribeExternalAudio(from audioURL: URL) async {
        self.transcribeExternalAudioCalled = true
    }

    // Test helper
    func simulateState(recording: Bool, transcribing: Bool) {
        self.isRecording = recording
        self.isTranscribing = transcribing
        self.isRecordingSubject.send(recording)
        self.isTranscribingSubject.send(transcribing)
    }
}
