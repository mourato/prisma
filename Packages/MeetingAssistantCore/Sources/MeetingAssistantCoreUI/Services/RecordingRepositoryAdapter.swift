import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Adapter that implements `RecordingRepository` using `RecordingManager`.
@MainActor
public final class RecordingRepositoryAdapter: RecordingRepository {
    private let recordingManager: RecordingManager

    public init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
    }

    public func startRecording(to outputURL: URL, retryCount: Int) async throws {
        // `RecordingManager` owns URL creation internally.
        await recordingManager.startRecording(source: .microphone)
    }

    public func stopRecording() async throws -> URL? {
        let recordedPath = recordingManager.currentMeeting?.audioFilePath
        await recordingManager.stopRecording(transcribe: false)

        guard let recordedPath else { return nil }
        return URL(fileURLWithPath: recordedPath)
    }

    public func hasPermission() async -> Bool {
        await recordingManager.checkPermission(for: RecordingSource.microphone)
        return recordingManager.hasRequiredPermissions
    }

    public func requestPermission() async {
        await recordingManager.requestPermission(for: RecordingSource.microphone)
    }

    public func getPermissionState() async -> DomainPermissionState {
        map(recordingManager.permissionStatus.microphonePermission.state)
    }

    public func openSettings() async {
        recordingManager.openMicrophoneSettings()
    }

    private func map(_ state: PermissionState) -> DomainPermissionState {
        switch state {
        case .granted:
            .granted
        case .denied:
            .denied
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        }
    }
}
