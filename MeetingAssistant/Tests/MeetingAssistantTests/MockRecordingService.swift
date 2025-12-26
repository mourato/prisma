import Foundation
import Combine
@testable import MeetingAssistantCore

@MainActor
class MockRecordingService: RecordingServiceProtocol {
    // Properties
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var currentMeeting: Meeting? = nil
    var transcriptionStatus = TranscriptionStatus()
    var permissionStatus = PermissionStatusManager()
    
    // Publishers
    var isRecordingSubject = PassthroughSubject<Bool, Never>()
    var isTranscribingSubject = PassthroughSubject<Bool, Never>()
    var currentMeetingSubject = PassthroughSubject<Meeting?, Never>()
    
    var isRecordingPublisher: AnyPublisher<Bool, Never> { isRecordingSubject.eraseToAnyPublisher() }
    var isTranscribingPublisher: AnyPublisher<Bool, Never> { isTranscribingSubject.eraseToAnyPublisher() }
    var currentMeetingPublisher: AnyPublisher<Meeting?, Never> { currentMeetingSubject.eraseToAnyPublisher() }
    
    // Track calls
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var checkPermissionCalled = false
    var requestPermissionCalled = false
    var openMicrophoneSettingsCalled = false
    var openPermissionSettingsCalled = false
    
    func startRecording() async {
        startRecordingCalled = true
        isRecording = true
        isRecordingSubject.send(true)
    }
    
    func stopRecording() async {
        stopRecordingCalled = true
        isRecording = false
        isRecordingSubject.send(false)
    }
    
    func checkPermission() async {
        checkPermissionCalled = true
    }
    
    func requestPermission() async {
        requestPermissionCalled = true
    }
    
    func openMicrophoneSettings() {
        openMicrophoneSettingsCalled = true
    }
    
    func openPermissionSettings() {
        openPermissionSettingsCalled = true
    }
    
    // Test helper
    func simulateState(recording: Bool, transcribing: Bool) {
        isRecording = recording
        isTranscribing = transcribing
        isRecordingSubject.send(recording)
        isTranscribingSubject.send(transcribing)
    }
}
