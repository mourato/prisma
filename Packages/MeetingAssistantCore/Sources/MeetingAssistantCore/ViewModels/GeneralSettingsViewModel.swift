import AppKit
import Foundation
import SwiftUI

@MainActor
public class GeneralSettingsViewModel: ObservableObject {
    private let settingsStore: AppSettingsStore

    @Published public var autoStartRecording: Bool {
        didSet {
            self.settingsStore.autoStartRecording = self.autoStartRecording
        }
    }

    @Published public var recordingsPath: String {
        didSet {
            self.settingsStore.recordingsDirectory = self.recordingsPath
        }
    }

    @Published public var audioFormat: AppSettingsStore.AudioFormat {
        didSet {
            self.settingsStore.audioFormat = self.audioFormat
        }
    }

    @Published public var shouldMergeAudioFiles: Bool {
        didSet {
            self.settingsStore.shouldMergeAudioFiles = self.shouldMergeAudioFiles
        }
    }

    @Published public var selectedLanguage: AppLanguage {
        didSet {
            self.settingsStore.selectedLanguage = self.selectedLanguage
        }
    }

    @Published public var showSettingsOnLaunch: Bool {
        didSet {
            self.settingsStore.showSettingsOnLaunch = self.showSettingsOnLaunch
        }
    }

    public init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore
        self.autoStartRecording = settingsStore.autoStartRecording
        self.recordingsPath = settingsStore.recordingsDirectory
        self.audioFormat = settingsStore.audioFormat
        self.shouldMergeAudioFiles = settingsStore.shouldMergeAudioFiles
        self.selectedLanguage = settingsStore.selectedLanguage
        self.showSettingsOnLaunch = settingsStore.showSettingsOnLaunch
    }

    public func selectRecordingsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        // Use current path as starting point if valid
        if !self.recordingsPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: self.recordingsPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            self.recordingsPath = url.path
        }
    }
}
