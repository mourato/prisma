import Combine
import Foundation
import SwiftUI

@MainActor
public class RecordingViewModel: ObservableObject {
    // MARK: - Dependencies

    private let recordingManager: any RecordingServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    @Published public var isRecording: Bool = false
    @Published public var isTranscribing: Bool = false
    @Published public var arePermissionsGranted: Bool = false
    @Published public var currentMeeting: Meeting?
    @Published public var isModelLoaded: Bool = false
    // @Published public var permissionStatus: PermissionStatusManager // Refactored to use Child ViewModel

    // MARK: - Child ViewModels

    public let transcriptionViewModel: TranscriptionViewModel
    public let permissionViewModel: PermissionViewModel

    // MARK: - Computed Properties

    public var statusText: String {
    public var statusText: String {
        if self.isRecording {
            NSLocalizedString("status.recording", bundle: .safeModule, comment: "Recording status")
        } else if self.isTranscribing {
            NSLocalizedString("status.transcribing", bundle: .safeModule, comment: "Transcribing status")
        } else {
            NSLocalizedString("status.waiting", bundle: .safeModule, comment: "Waiting status")
        }
    }

    // MARK: - Initialization

    // MARK: - Initialization

    public init(recordingManager: some RecordingServiceProtocol = RecordingManager.shared) {
        self.recordingManager = recordingManager

        // Initialize child ViewModels
        self.transcriptionViewModel = TranscriptionViewModel(status: recordingManager.transcriptionStatus)

        self.permissionViewModel = PermissionViewModel(
            manager: recordingManager.permissionStatus,
            requestMicrophone: { await recordingManager.requestPermission() },
            requestScreen: { await recordingManager.requestPermission() },
            openMicrophoneSettings: { recordingManager.openMicrophoneSettings() },
            openScreenSettings: { recordingManager.openPermissionSettings() }
        )

        self.setupBindings()
    }

    // MARK: - Methods

    public func startRecording() async {
        await self.recordingManager.startRecording()
    }

    public func stopRecording() async {
        await self.recordingManager.stopRecording()
    }

    public func checkPermission() async {
        await self.recordingManager.checkPermission()
    }

    public func requestPermission() async {
        await self.recordingManager.requestPermission()
    }

    public func openMicrophoneSettings() {
        self.recordingManager.openMicrophoneSettings()
    }

    public func openPermissionSettings() {
        self.recordingManager.openPermissionSettings()
    }

    /// Import and transcribe an external audio file.
    /// - Parameter url: Path to the audio file (m4a, mp3, wav).
    public func transcribeFile(at url: URL) async {
        await self.recordingManager.transcribeExternalAudio(from: url)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        self.recordingManager.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$isRecording)

        self.recordingManager.isTranscribingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$isTranscribing)

        self.recordingManager.currentMeetingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$currentMeeting)

        // Note: permissionStatus and transcriptionStatus are reference types (Classes),
        // so we don't necessarily need to re-assign them if the reference itself doesn't change.
        // However, if RecordingManager replaces them, we should observe that.
        // Assuming they are constant references in RecordingManager for now based on previous code.

        // Observe model state
        FluidAIModelManager.shared.$modelState
            .receive(on: DispatchQueue.main)
            .map { $0 == .loaded }
            .assign(to: &self.$isModelLoaded)

        // Observe permission state from child ViewModel
        self.permissionViewModel.$microphoneState
            .combineLatest(self.permissionViewModel.$screenState)
            .map { mic, screen in mic == .granted && screen == .granted }
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$arePermissionsGranted)
    }
}
