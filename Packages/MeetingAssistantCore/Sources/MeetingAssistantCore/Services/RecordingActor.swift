import Foundation
import os.log

/// Actor que isola o estado de gravação para thread safety seguindo Swift 6 concurrency.
/// Gerencia estado mutável compartilhado entre threads, evitando race conditions.
public actor RecordingActor {
    // MARK: - Estado Isolado

    private var isRecording = false
    private var isTranscribing = false
    private var currentMeeting: Meeting?
    private var lastError: Error?
    private var hasRequiredPermissions = false
    private var micAudioURL: URL?
    private var systemAudioURL: URL?
    private var mergedAudioURL: URL?

    // MARK: - Acesso Thread-Safe ao Estado

    public var recordingState: Bool {
        self.isRecording
    }

    public var transcribingState: Bool {
        self.isTranscribing
    }

    public var currentMeetingState: Meeting? {
        self.currentMeeting
    }

    public var lastErrorState: Error? {
        self.lastError
    }

    public var permissionsState: Bool {
        self.hasRequiredPermissions
    }

    public var micAudioURLState: URL? {
        self.micAudioURL
    }

    public var systemAudioURLState: URL? {
        self.systemAudioURL
    }

    public var mergedAudioURLState: URL? {
        self.mergedAudioURL
    }

    // MARK: - Métodos de Modificação

    public func setRecording(_ value: Bool) {
        self.isRecording = value
        AppLogger.debug("Recording state updated to: \(value)", category: .recordingManager)
    }

    public func setTranscribing(_ value: Bool) {
        self.isTranscribing = value
        AppLogger.debug("Transcribing state updated to: \(value)", category: .recordingManager)
    }

    public func setCurrentMeeting(_ meeting: Meeting?) {
        self.currentMeeting = meeting
        AppLogger.debug("Current meeting updated: \(meeting?.app.displayName ?? "nil")", category: .recordingManager)
    }

    public func setLastError(_ error: Error?) {
        self.lastError = error
        if let error {
            AppLogger.error("Last error updated", category: .recordingManager, error: error)
        }
    }

    public func setPermissions(_ hasPermissions: Bool) {
        self.hasRequiredPermissions = hasPermissions
        AppLogger.debug("Permissions state updated to: \(hasPermissions)", category: .recordingManager)
    }

    public func setMicAudioURL(_ url: URL?) {
        self.micAudioURL = url
    }

    public func setSystemAudioURL(_ url: URL?) {
        self.systemAudioURL = url
    }

    public func setMergedAudioURL(_ url: URL?) {
        self.mergedAudioURL = url
    }

    public func clearTemporaryURLs() {
        self.micAudioURL = nil
        self.systemAudioURL = nil
        self.mergedAudioURL = nil
    }

    // MARK: - Utilitários

    public func createMeeting(app: MeetingApp) -> Meeting {
        let meeting = Meeting(app: app)
        self.currentMeeting = meeting
        return meeting
    }

    public func updateMeetingEndTime() {
        self.currentMeeting?.endTime = Date()
    }

    public func updateMeetingAudioPath(_ path: String) {
        self.currentMeeting?.audioFilePath = path
    }

    public func reset() {
        self.isRecording = false
        self.isTranscribing = false
        self.currentMeeting = nil
        self.lastError = nil
        self.micAudioURL = nil
        self.systemAudioURL = nil
        self.mergedAudioURL = nil
    }
}
