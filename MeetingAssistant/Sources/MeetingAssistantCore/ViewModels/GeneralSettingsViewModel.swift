import AppKit
import Foundation
import SwiftUI

@MainActor
public class GeneralSettingsViewModel: ObservableObject {
    @AppStorage("autoStartRecording") public var autoStartRecording = true
    @AppStorage("recordingsDirectory") public var recordingsPath = ""

    public init() {}

    public func selectRecordingsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            self.recordingsPath = url.path
        }
    }
}
