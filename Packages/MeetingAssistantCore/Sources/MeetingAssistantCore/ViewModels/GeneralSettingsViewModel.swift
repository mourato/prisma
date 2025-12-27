import AppKit
import Foundation
import SwiftUI

@MainActor
public class GeneralSettingsViewModel: ObservableObject {
    private let settingsStore = AppSettingsStore.shared

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

    public init() {
        self.autoStartRecording = AppSettingsStore.shared.autoStartRecording
        self.recordingsPath = AppSettingsStore.shared.recordingsDirectory
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
