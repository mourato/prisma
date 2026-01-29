import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
public class GeneralSettingsViewModel: ObservableObject {
    private let settingsStore: AppSettingsStore

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

    @Published public var muteOutputDuringRecording: Bool {
        didSet {
            settingsStore.muteOutputDuringRecording = muteOutputDuringRecording
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

    @Published public var availableDevices: [AudioInputDevice] = []

    private let deviceManager = AudioDeviceManager()
    private var cancellables = Set<AnyCancellable>()

    public init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore
        autoStartRecording = settingsStore.autoStartRecording
        recordingsPath = settingsStore.recordingsDirectory
        audioFormat = settingsStore.audioFormat
        shouldMergeAudioFiles = settingsStore.shouldMergeAudioFiles
        selectedLanguage = settingsStore.selectedLanguage
        showSettingsOnLaunch = settingsStore.showSettingsOnLaunch
        muteOutputDuringRecording = settingsStore.muteOutputDuringRecording
        recordingIndicatorEnabled = settingsStore.recordingIndicatorEnabled
        recordingIndicatorStyle = settingsStore.recordingIndicatorStyle
        recordingIndicatorPosition = settingsStore.recordingIndicatorPosition

        setupDeviceObservation()
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
}
