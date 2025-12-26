import Combine
import Foundation
import KeyboardShortcuts
import os.log

/// Manages global keyboard shortcuts for the application.
@MainActor
public class GlobalShortcutManager: ObservableObject {
    public static let shared = GlobalShortcutManager()

    private let logger = Logger(subsystem: "MeetingAssistant", category: "GlobalShortcutManager")

    // MARK: - Published State

    /// Callback triggered when the shortcut is activated.
    public var onShortcutActivated: (() -> Void)?

    // MARK: - Initialization

    private init() {
        setupShortcuts()
    }

    // MARK: - Private Methods

    private func setupShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                self?.handleHotKeyActivation()
            }
        }
    }

    private func handleHotKeyActivation() {
        logger.info("Global shortcut activated")
        onShortcutActivated?()
    }

    /// Register the global hotkey.
    /// kept for compatibility, but KeyboardShortcuts handles this automatically.
    public func registerHotKey() {
        // No-op with KeyboardShortcuts
    }

    /// Unregister the current global hotkey.
    public func unregisterHotKey() {
        // No-op with KeyboardShortcuts
    }
}
