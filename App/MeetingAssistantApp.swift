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
        let isMeetingNotesPanelVisible: Bool
    }

    let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "AppDelegate")
    var statusItem: NSStatusItem?
    var contextMenu: NSMenu?
    var dictateMenuItem: NSMenuItem?
    var recordMeetingMenuItem: NSMenuItem?
    var assistantMenuItem: NSMenuItem?
    var cancelRecordingMenuItem: NSMenuItem?
    lazy var recordingManager: RecordingManager = .shared
    let settingsStore = AppSettingsStore.shared
    lazy var floatingIndicatorController = FloatingRecordingIndicatorController()
    lazy var meetingNotesPanelController = MeetingNotesFloatingPanelController()
    lazy var globalShortcutController = GlobalShortcutController(recordingManager: RecordingManager.shared)
    lazy var assistantVoiceCommandService = AssistantVoiceCommandService(
        indicator: floatingIndicatorController
    )
    lazy var assistantShortcutController = AssistantShortcutController(
        assistantService: assistantVoiceCommandService
    )
    lazy var cloudSyncCoordinator = CloudSyncCoordinator()
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
    var cloudSyncObserversConfigured = false
    var lastRecordingUIRenderState: RecordingUIRenderState?
}

@MainActor
final class SettingsWindowController {
    private enum Layout {
        static let defaultContentSize = NSSize(width: 900, height: 640)
        static let sidebarWidthRange: ClosedRange<CGFloat> = 220...260
        static let frameMargin: CGFloat = 12
    }

    private var window: NSWindow?

    func showSettingsWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.setContentSize(Layout.defaultContentSize)
        settingsWindow.contentMinSize = Layout.defaultContentSize
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

        let layoutEvaluation = evaluatePersistedLayoutState()
        resetPersistedLayoutIfNeeded(using: layoutEvaluation)

        settingsWindow.setFrameAutosaveName(AppIdentity.settingsWindowAutosaveName)
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.contentViewController = NSHostingController(rootView: SettingsView())

        if layoutEvaluation.shouldCenterWindow {
            settingsWindow.center()
        }

        if layoutEvaluation.requiresFrameClamp {
            clampWindowFrameIfNeeded(settingsWindow)
        }

        settingsWindow.makeKeyAndOrderFront(nil)

        if layoutEvaluation.requiresFrameClamp {
            clampWindowFrameIfNeeded(settingsWindow)
        }

        window = settingsWindow
        NSApp.activate(ignoringOtherApps: true)
    }

    private func evaluatePersistedLayoutState() -> SettingsWindowLayoutStateEvaluation {
        SettingsWindowLayoutStateEvaluator.evaluate(
            visibleScreenFrames: NSScreen.screens.map(\.visibleFrame),
            defaultContentSize: Layout.defaultContentSize,
            sidebarWidthRange: Layout.sidebarWidthRange
        )
    }

    private func resetPersistedLayoutIfNeeded(using evaluation: SettingsWindowLayoutStateEvaluation) {
        guard evaluation.shouldResetPersistedLayout else {
            return
        }

        let defaults = UserDefaults.standard
        for key in evaluation.keysToReset {
            defaults.removeObject(forKey: key)
        }
    }

    private func clampWindowFrameIfNeeded(_ window: NSWindow) {
        guard let targetScreenFrame = bestVisibleFrame(for: window.frame) else {
            return
        }

        let clampedFrame = clampedFrame(for: window.frame, within: targetScreenFrame)
        guard !window.frame.equalTo(clampedFrame) else {
            return
        }

        window.setFrame(clampedFrame, display: false)
    }

    private func bestVisibleFrame(for frame: NSRect) -> NSRect? {
        let midpoint = NSPoint(x: frame.midX, y: frame.midY)

        if let midpointScreen = NSScreen.screens.first(where: { $0.visibleFrame.contains(midpoint) }) {
            return midpointScreen.visibleFrame
        }

        if let mainScreenFrame = NSScreen.main?.visibleFrame {
            return mainScreenFrame
        }

        return NSScreen.screens.first?.visibleFrame
    }

    private func clampedFrame(for frame: NSRect, within visibleFrame: NSRect) -> NSRect {
        let availableWidth = max(visibleFrame.width - (Layout.frameMargin * 2), 0)
        let availableHeight = max(visibleFrame.height - (Layout.frameMargin * 2), 0)

        let width = min(frame.width, availableWidth)
        let height = min(frame.height, availableHeight)

        let maxX = visibleFrame.maxX - Layout.frameMargin - width
        let maxY = visibleFrame.maxY - Layout.frameMargin - height

        let originX = min(max(frame.minX, visibleFrame.minX + Layout.frameMargin), maxX)
        let originY = min(max(frame.minY, visibleFrame.minY + Layout.frameMargin), maxY)

        return NSRect(x: originX, y: originY, width: width, height: height)
    }
}
