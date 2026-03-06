import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore
import os
import SwiftUI

/// Main entry point for the Prisma app.
/// Runs as a menu bar application without a dock icon.
@main
struct MeetingAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        clearLegacyLanguageOverrideIfNeeded()
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink {
                    Text("settings.title".localized + "...")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

private func clearLegacyLanguageOverrideIfNeeded() {
    let defaults = UserDefaults.standard
    let selectedLanguage = defaults.string(forKey: "selectedLanguage")

    // Keep system language behavior stable across launches, even if a stale override exists.
    if selectedLanguage == nil || selectedLanguage == "system" {
        defaults.removeObject(forKey: "AppleLanguages")
    }
}

extension ShortcutDefinition {
    var menuDisplayString: String {
        let modifierSymbols = modifiers.map { modifier in
            switch modifier {
            case .leftCommand, .rightCommand, .command: "⌘"
            case .leftShift, .rightShift, .shift: "⇧"
            case .leftOption, .rightOption, .option: "⌥"
            case .leftControl, .rightControl, .control: "⌃"
            case .fn: "Fn"
            }
        }

        var tokens = modifierSymbols
        if let primaryKey {
            tokens.append(primaryKey.display)
        } else if trigger == .doubleTap, let first = modifierSymbols.first {
            tokens.append(first)
        }

        return tokens.joined()
    }
}

/// App delegate for menu bar setup and lifecycle management.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    struct RecordingUIRenderState: Equatable {
        let isRecording: Bool
        let isStarting: Bool
        let isTranscribing: Bool
        let isAssistantRecording: Bool
        let isAssistantProcessing: Bool
        let meetingTypeRawValue: String?
    }

    let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "AppDelegate")
    var statusItem: NSStatusItem?
    var contextMenu: NSMenu?
    var dictateMenuItem: NSMenuItem?
    var recordMeetingMenuItem: NSMenuItem?
    var assistantMenuItem: NSMenuItem?
    lazy var recordingManager: RecordingManager = .shared
    let settingsStore = AppSettingsStore.shared
    lazy var floatingIndicatorController = FloatingRecordingIndicatorController()
    lazy var globalShortcutController = GlobalShortcutController(recordingManager: RecordingManager.shared)
    lazy var assistantVoiceCommandService = AssistantVoiceCommandService(
        indicator: floatingIndicatorController
    )
    lazy var assistantShortcutController = AssistantShortcutController(
        assistantService: assistantVoiceCommandService
    )
    lazy var recordingCancelShortcutController = RecordingCancelShortcutController(
        stateProvider: { [weak self] in
            guard let self else {
                return RecordingCancelShortcutState(
                    isRecordingManagerCaptureActive: false,
                    isAssistantCaptureActive: false
                )
            }
            return RecordingCancelShortcutState(
                isRecordingManagerCaptureActive: recordingManager.isRecording || recordingManager.isStartingRecording,
                isAssistantCaptureActive: assistantVoiceCommandService.isRecording
            )
        },
        cancelRecordingManagerCapture: { [weak self] in
            await self?.recordingManager.cancelRecording()
        },
        cancelAssistantCapture: { [weak self] in
            await self?.assistantVoiceCommandService.cancelRecording()
        }
    )
    lazy var onboardingController = OnboardingWindowController()
    lazy var settingsWindowController = SettingsWindowController()
    var cancellables = Set<AnyCancellable>()
    var dockObserver: AnyCancellable?
    var lastRecordingUIRenderState: RecordingUIRenderState?
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func showSettingsWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.styleMask.insert(.fullSizeContentView)
        settingsWindow.title = "settings.title".localized
        settingsWindow.titleVisibility = .hidden
        settingsWindow.titlebarAppearsTransparent = true
        settingsWindow.toolbarStyle = .unified
        settingsWindow.toolbar = NSToolbar(identifier: NSToolbar.Identifier(AppIdentity.settingsToolbarIdentifier))
        settingsWindow.isMovableByWindowBackground = false
        settingsWindow.tabbingMode = .disallowed
        if #available(macOS 11.0, *) {
            settingsWindow.titlebarSeparatorStyle = .none
        }
        settingsWindow.setFrameAutosaveName(AppIdentity.settingsWindowAutosaveName)
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)

        window = settingsWindow
        NSApp.activate(ignoringOtherApps: true)
    }
}
