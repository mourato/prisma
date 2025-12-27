import Foundation
import KeyboardShortcuts
import SwiftUI

@MainActor
public class ShortcutSettingsViewModel: ObservableObject {
    public init() {}

    public func resetShortcuts() {
        KeyboardShortcuts.reset(.toggleRecording)
    }
}
