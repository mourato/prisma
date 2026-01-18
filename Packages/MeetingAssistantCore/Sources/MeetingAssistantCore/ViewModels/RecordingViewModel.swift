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
    @Published public var selectedSource: RecordingSource = .all
    @Published public var displayDuration: String = "00:00"
    private var timer: AnyCancellable?

    // MARK: - Child ViewModels

    public let transcriptionViewModel: TranscriptionViewModel
    public let permissionViewModel: PermissionViewModel

    // MARK: - Computed Properties

    public var statusText: String {
        if self.isRecording {
            "status.recording".localized
        } else if self.isTranscribing {
            "status.transcribing".localized
        } else {
            "status.waiting".localized
        }
    }

    // MARK: - View Logic

    public var recordButtonTitle: String {
        if self.isRecording {
            return "menubar.stop_recording".localized
        }

        return self.isModelLoaded
            ? "menubar.start_recording".localized
            : "settings.transcriptions.loading".localized
    }

    public var recordButtonIcon: String {
        if self.isRecording {
            return "stop.fill"
        }
        return self.isModelLoaded ? "record.circle" : "hourglass"
    }

    public var canStartRecording: Bool {
        self.isModelLoaded
    }

    // MARK: - Initialization

    // MARK: - Initialization

    public init(recordingManager: some RecordingServiceProtocol) {
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

    public func startRecording(source: RecordingSource? = nil) async {
        // If specific source requested, use it (and maybe update selection?)
        // Or just use it for this session. User request implies clicking arrow chooses what to record.
        // If I click "Mic Only" in menu, I expect it to start recording Mic Only.
        // Does it change the DEFAULT for the main button?
        // User said: "se eu clicar no botão em si, ele inicia a gravação de tudo... mas se eu clicar no canto direito, posso escolher..."
        // This implies main button is ALWAYS "Tudo" or "Default".
        // Let's support passing source.
        let sourceToUse = source ?? .all
        self.selectedSource = sourceToUse // Sync UI state
        await self.recordingManager.startRecording(source: sourceToUse)
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
            .sink { [weak self] meeting in
                self?.currentMeeting = meeting
                if meeting != nil {
                    self?.startTimer()
                } else {
                    self?.stopTimer()
                }
            }
            .store(in: &self.cancellables)

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

    private func startTimer() {
        self.timer?.cancel()
        self.timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateDisplayDuration()
            }
    }

    private func stopTimer() {
        self.timer?.cancel()
        self.timer = nil
        self.displayDuration = "00:00"
    }

    private func updateDisplayDuration() {
        guard let meeting = self.currentMeeting else { return }
        let duration = Int(meeting.duration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60

        if hours > 0 {
            self.displayDuration = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            self.displayDuration = String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
