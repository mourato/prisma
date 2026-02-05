import AppKit
import ApplicationServices
import Carbon
import Foundation

@MainActor
struct TranscriptionDeliveryService {
    static func deliver(
        transcription: Transcription,
        settings: DeliverySettingsConfig = AppSettingsStore.shared,
        pasteboard: PasteboardServiceProtocol = PasteboardService.shared
    ) {
        // Only allow auto-copy/paste for dictations.
        // Meeting recordings and imported files should not trigger this.
        guard transcription.meeting.isDictation else { return }

        guard settings.autoCopyTranscriptionToClipboard || settings.autoPasteTranscriptionToActiveApp else { return }

        let textToCopy = transcriptionDeliveryText(from: transcription)
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)

        if settings.autoPasteTranscriptionToActiveApp {
            pasteboard.setString(textToCopy, forType: .string) // Ensure it's ready for pasting
            pasteTranscriptionIntoActiveApp()
        }
    }

    private static func transcriptionDeliveryText(from transcription: Transcription) -> String {
        let candidate = transcription.processedContent?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate, !candidate.isEmpty {
            return candidate
        }
        return transcription.rawText
    }

    private static func pasteTranscriptionIntoActiveApp() {
        guard AccessibilityPermissionService.isTrusted() else {
            AppLogger.error(
                "Accessibility permission missing for auto-paste",
                category: .recordingManager
            )
            return
        }

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
