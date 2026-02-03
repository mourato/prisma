import AppKit
@preconcurrency import ApplicationServices
import Carbon
import Foundation

@MainActor
public final class AssistantTextSelectionService {
    struct PasteboardSnapshot {
        let items: [NSPasteboardItem]
        let changeCount: Int
    }

    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func captureSelectedText() async throws -> (text: String, snapshot: PasteboardSnapshot) {
        guard hasAccessibilityPermission() else {
            throw AssistantVoiceCommandError.accessibilityPermissionRequired
        }

        let snapshot = PasteboardSnapshot(
            items: pasteboard.pasteboardItems ?? [],
            changeCount: pasteboard.changeCount
        )

        simulateCopy()

        let didChange = await waitForPasteboardChange(from: snapshot.changeCount)
        guard didChange else {
            throw AssistantVoiceCommandError.noSelectionFound
        }

        guard let selectedText = pasteboard.string(forType: .string),
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AssistantVoiceCommandError.noSelectionFound
        }

        return (selectedText, snapshot)
    }

    func replaceSelectedText(with text: String, restoring snapshot: PasteboardSnapshot) async throws {
        guard hasAccessibilityPermission() else {
            throw AssistantVoiceCommandError.accessibilityPermissionRequired
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCountAfterWrite = pasteboard.changeCount

        simulatePaste()
        try? await Task.sleep(nanoseconds: 120_000_000)

        if pasteboard.changeCount == changeCountAfterWrite {
            restorePasteboard(snapshot)
        }
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        if !snapshot.items.isEmpty {
            pasteboard.writeObjects(snapshot.items)
        }
    }

    private func waitForPasteboardChange(from changeCount: Int) async -> Bool {
        let maxAttempts = 10
        for _ in 0..<maxAttempts {
            if pasteboard.changeCount != changeCount {
                return true
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    private func hasAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        return false
    }

    private func simulateCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_C),
            keyDown: true
        )
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_C),
            keyDown: false
        )
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        )
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        )
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
