import AppKit
import Combine
import Foundation
import os
import ServiceManagement
import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
public class GeneralSettingsViewModel: ObservableObject {
    private let settingsStore: AppSettingsStore
    private let storage: StorageService

    @Published public var autoStartRecording: Bool {
        didSet {
            settingsStore.autoStartRecording = autoStartRecording
        }
    }

    @Published public var recordingsPath: String {
        didSet {
            settingsStore.recordingsDirectory = recordingsPath
        }
    }

    @Published public var audioFormat: AppSettingsStore.AudioFormat {
        didSet {
            settingsStore.audioFormat = audioFormat
        }
    }

    @Published public var shouldMergeAudioFiles: Bool {
        didSet {
            settingsStore.shouldMergeAudioFiles = shouldMergeAudioFiles
        }
    }

    @Published public var selectedLanguage: AppLanguage {
        didSet {
            settingsStore.selectedLanguage = selectedLanguage
        }
    }

    @Published public var showSettingsOnLaunch: Bool {
        didSet {
            settingsStore.showSettingsOnLaunch = showSettingsOnLaunch
        }
    }

    @Published public var autoCopyTranscriptionToClipboard: Bool {
        didSet {
            settingsStore.autoCopyTranscriptionToClipboard = autoCopyTranscriptionToClipboard
        }
    }

    @Published public var autoPasteTranscriptionToActiveApp: Bool {
        didSet {
            settingsStore.autoPasteTranscriptionToActiveApp = autoPasteTranscriptionToActiveApp
        }
    }

    @Published public var muteOutputDuringRecording: Bool {
        didSet {
            settingsStore.muteOutputDuringRecording = muteOutputDuringRecording
        }
    }

    @Published public var useSystemDefaultInput: Bool {
        didSet {
            settingsStore.useSystemDefaultInput = useSystemDefaultInput
        }
    }

    @Published public var recordingIndicatorEnabled: Bool {
        didSet {
            settingsStore.recordingIndicatorEnabled = recordingIndicatorEnabled
        }
    }

    @Published public var recordingIndicatorStyle: RecordingIndicatorStyle {
        didSet {
            settingsStore.recordingIndicatorStyle = recordingIndicatorStyle
        }
    }

    @Published public var recordingIndicatorPosition: RecordingIndicatorPosition {
        didSet {
            settingsStore.recordingIndicatorPosition = recordingIndicatorPosition
        }
    }

    @Published public var autoDeleteTranscriptions: Bool {
        didSet {
            settingsStore.autoDeleteTranscriptions = autoDeleteTranscriptions
        }
    }

    @Published public var autoDeletePeriodDays: Int {
        didSet {
            settingsStore.autoDeletePeriodDays = autoDeletePeriodDays
        }
    }

    // MARK: - Sound Feedback Properties

    @Published public var soundFeedbackEnabled: Bool {
        didSet {
            settingsStore.soundFeedbackEnabled = soundFeedbackEnabled
        }
    }

    @Published public var recordingStartSound: SoundFeedbackSound {
        didSet {
            settingsStore.recordingStartSound = recordingStartSound
        }
    }

    @Published public var recordingStopSound: SoundFeedbackSound {
        didSet {
            settingsStore.recordingStopSound = recordingStopSound
        }
    }

    @Published public var showInDock: Bool {
        didSet {
            settingsStore.showInDock = showInDock
        }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            // Avoid infinite loop if we revert the state
            guard launchAtLogin != settingsStore.launchAtLogin else { return }

            settingsStore.launchAtLogin = launchAtLogin
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    @Published public var availableDevices: [AudioInputDevice] = []
    @Published public var showCleanupSuccessAlert = false
    @Published public var showCleanupConfirmationDialog = false
    @Published public var cleanupInProgress = false
    @Published public var cleanupError: String?
    @Published public var cleanupPreview: RetentionCleanupPreview?

    private let deviceManager = AudioDeviceManager()
    private var cancellables = Set<AnyCancellable>()
    private nonisolated static let logger = Logger(subsystem: "MeetingAssistant", category: "GeneralSettingsViewModel")

    public init(
        settingsStore: AppSettingsStore = .shared,
        storage: StorageService = FileSystemStorageService.shared
    ) {
        self.settingsStore = settingsStore
        self.storage = storage
        autoStartRecording = settingsStore.autoStartRecording
        recordingsPath = settingsStore.recordingsDirectory
        audioFormat = settingsStore.audioFormat
        shouldMergeAudioFiles = settingsStore.shouldMergeAudioFiles
        selectedLanguage = settingsStore.selectedLanguage
        showSettingsOnLaunch = settingsStore.showSettingsOnLaunch
        autoCopyTranscriptionToClipboard = settingsStore.autoCopyTranscriptionToClipboard
        autoPasteTranscriptionToActiveApp = settingsStore.autoPasteTranscriptionToActiveApp
        muteOutputDuringRecording = settingsStore.muteOutputDuringRecording
        useSystemDefaultInput = settingsStore.useSystemDefaultInput
        recordingIndicatorEnabled = settingsStore.recordingIndicatorEnabled
        recordingIndicatorStyle = settingsStore.recordingIndicatorStyle
        recordingIndicatorPosition = settingsStore.recordingIndicatorPosition
        autoDeleteTranscriptions = settingsStore.autoDeleteTranscriptions
        autoDeletePeriodDays = settingsStore.autoDeletePeriodDays
        soundFeedbackEnabled = settingsStore.soundFeedbackEnabled
        recordingStartSound = settingsStore.recordingStartSound
        recordingStopSound = settingsStore.recordingStopSound
        showInDock = settingsStore.showInDock
        launchAtLogin = settingsStore.launchAtLogin

        setupDeviceObservation()
    }

    public var cleanupConfirmationMessage: String {
        let preview = cleanupPreview

        let audioCount = preview?.audioCount ?? 0
        let transcriptionCount = preview?.transcriptionCount ?? 0

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        let audioSize = formatter.string(fromByteCount: preview?.totalAudioBytes ?? 0)
        let transcriptionSize = formatter.string(fromByteCount: preview?.totalTranscriptionBytes ?? 0)

        return String(
            format: "settings.storage.cleanup_confirm_message".localized,
            audioCount,
            audioSize,
            transcriptionCount,
            transcriptionSize
        )
    }

    private func setupDeviceObservation() {
        deviceManager.$availableInputDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.updateAvailableDevices(devices)
            }
            .store(in: &cancellables)
    }

    private func updateAvailableDevices(_ detectedDevices: [AudioInputDevice]) {
        let priorityList = settingsStore.audioDevicePriority

        // 1. Start with devices in priority list
        var result: [AudioInputDevice] = []

        for uid in priorityList {
            if let detected = detectedDevices.first(where: { $0.id == uid }) {
                result.append(detected)
            } else {
                // Device in priority list but not currently connected
                // We keep it in the list (marked as unavailable) so the user doesn't lose their priority setting
                result.append(AudioInputDevice(id: uid, name: "Unknown Device (\(uid))", isAvailable: false))
            }
        }

        // 2. Add detected devices NOT in priority list at the end
        for detected in detectedDevices {
            if !priorityList.contains(detected.id) {
                result.append(detected)
            }
        }

        availableDevices = result
    }

    public func moveDevice(from offsets: IndexSet, to destination: Int) {
        availableDevices.move(fromOffsets: offsets, toOffset: destination)
        saveDevicePriority()
    }

    private func saveDevicePriority() {
        settingsStore.audioDevicePriority = availableDevices.map(\.id)
    }

    public func selectRecordingsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        // Use current path as starting point if valid
        if !recordingsPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: recordingsPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            recordingsPath = url.path
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            Self.logger.error("Failed to update launch at login: \(error.localizedDescription)")

            // Revert state on failure
            DispatchQueue.main.async { [weak self] in
                self?.launchAtLogin = !enabled
            }
        }
    }

    public func performCleanup() {
        guard !cleanupInProgress else { return }

        cleanupError = nil
        cleanupPreview = nil
        cleanupInProgress = true

        Task { [weak self] in
            guard let self else { return }

            do {
                let preview = try await storage.computeRetentionCleanupPreview(olderThanDays: autoDeletePeriodDays)
                cleanupPreview = preview
                showCleanupConfirmationDialog = true
            } catch {
                cleanupError = error.localizedDescription
            }

            cleanupInProgress = false
        }
    }

    public func confirmCleanup() {
        guard !cleanupInProgress else { return }
        guard let preview = cleanupPreview else { return }

        cleanupError = nil
        cleanupInProgress = true

        Task { [weak self] in
            guard let self else { return }

            do {
                _ = try await storage.performRetentionCleanup(preview: preview)
                showCleanupSuccessAlert = true
            } catch {
                cleanupError = error.localizedDescription
            }

            cleanupInProgress = false
            cleanupPreview = nil
        }
    }
}
