import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation
import Vision

public struct ContextAwarenessCaptureOptions: Sendable {
    public let includeActiveApp: Bool
    public let includeClipboard: Bool
    public let includeWindowOCR: Bool
    public let includeAccessibilityText: Bool
    public let protectSensitiveApps: Bool
    public let redactSensitiveData: Bool
    public let excludedBundleIDs: [String]

    public init(
        includeActiveApp: Bool,
        includeClipboard: Bool,
        includeWindowOCR: Bool,
        includeAccessibilityText: Bool,
        protectSensitiveApps: Bool,
        redactSensitiveData: Bool,
        excludedBundleIDs: [String]
    ) {
        self.includeActiveApp = includeActiveApp
        self.includeClipboard = includeClipboard
        self.includeWindowOCR = includeWindowOCR
        self.includeAccessibilityText = includeAccessibilityText
        self.protectSensitiveApps = protectSensitiveApps
        self.redactSensitiveData = redactSensitiveData
        self.excludedBundleIDs = excludedBundleIDs
    }
}

public struct ContextAwarenessSnapshot: Sendable {
    public let activeAppName: String?
    public let activeWindowTitle: String?
    public let activeAccessibilityText: String?
    public let clipboardText: String?
    public let activeWindowOCRText: String?

    public var hasContent: Bool {
        activeAppName != nil || activeWindowTitle != nil || activeAccessibilityText != nil || clipboardText != nil || activeWindowOCRText != nil
    }

    public init(
        activeAppName: String?,
        activeWindowTitle: String?,
        activeAccessibilityText: String?,
        clipboardText: String?,
        activeWindowOCRText: String?
    ) {
        self.activeAppName = activeAppName
        self.activeWindowTitle = activeWindowTitle
        self.activeAccessibilityText = activeAccessibilityText
        self.clipboardText = clipboardText
        self.activeWindowOCRText = activeWindowOCRText
    }
}

@MainActor
public protocol ContextAwarenessServiceProtocol: Sendable {
    func captureSnapshot(options: ContextAwarenessCaptureOptions) -> ContextAwarenessSnapshot
    func makePostProcessingContext(from snapshot: ContextAwarenessSnapshot) -> String?
}

@MainActor
public final class ContextAwarenessService: ContextAwarenessServiceProtocol {
    public static let shared = ContextAwarenessService()

    private enum Constants {
        static let maxClipboardCharacters = 2_000
        static let maxOCRCharacters = 4_000
        static let maxAccessibilityCharacters = 4_000
        static let maxWindowTitleCharacters = 500
        static let maxAppNameCharacters = 200
        static let maxExcludedBundleIDs = 100
    }

    private enum RedactionPattern: String, CaseIterable {
        case email = #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#
        case url = #"\b(?:https?://|www\.)\S+\b"#
        case secretToken = #"\b(?:sk|rk|pk|ghp|xoxb|xoxp|AIza)[-_A-Za-z0-9]{12,}\b"#
        case longNumericSequence = #"\b(?:\d[ -]?){13,19}\b"#
    }

    private let defaultSensitiveBundleIDs: Set<String> = [
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.LastPass",
        "proton.pass.mac",
    ]

    private let replacementByPattern: [RedactionPattern: String] = [
        .email: "[REDACTED_EMAIL]",
        .url: "[REDACTED_URL]",
        .secretToken: "[REDACTED_SECRET]",
        .longNumericSequence: "[REDACTED_NUMBER]",
    ]

    private let regexOptions: NSRegularExpression.Options = [.caseInsensitive]
    private let redactionOrder: [RedactionPattern] = [.secretToken, .email, .url, .longNumericSequence]
    private var compiledRedactionRegexes: [RedactionPattern: NSRegularExpression] = [:]

    public init() {
        for pattern in RedactionPattern.allCases {
            if let regex = try? NSRegularExpression(pattern: pattern.rawValue, options: regexOptions) {
                compiledRedactionRegexes[pattern] = regex
            }
        }
    }

    public func captureSnapshot(options: ContextAwarenessCaptureOptions) -> ContextAwarenessSnapshot {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let normalizedExcludedBundleIDs = normalizedExcludedBundleIDs(options.excludedBundleIDs)

        if options.protectSensitiveApps,
           isSensitiveApp(frontmostApp, customExcludedBundleIDs: normalizedExcludedBundleIDs)
        {
            return ContextAwarenessSnapshot(
                activeAppName: nil,
                activeWindowTitle: nil,
                activeAccessibilityText: nil,
                clipboardText: nil,
                activeWindowOCRText: nil
            )
        }

        let activeApp = options.includeActiveApp ? frontmostApp : nil
        var appName = activeApp?.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        var windowTitle = options.includeActiveApp ? focusedWindowTitle(for: activeApp) : nil
        var accessibilityText = options.includeAccessibilityText ? focusedElementText(for: activeApp) : nil
        var clipboard = options.includeClipboard ? readClipboardText() : nil
        var ocrText = options.includeWindowOCR ? readActiveWindowOCRText(for: activeApp) : nil

        if options.redactSensitiveData {
            appName = redactSensitiveContent(appName)
            windowTitle = redactSensitiveContent(windowTitle)
            accessibilityText = redactSensitiveContent(accessibilityText)
            clipboard = redactSensitiveContent(clipboard)
            ocrText = redactSensitiveContent(ocrText)
        }

        return ContextAwarenessSnapshot(
            activeAppName: nonEmpty(limited(appName, maxCharacters: Constants.maxAppNameCharacters)),
            activeWindowTitle: nonEmpty(limited(windowTitle, maxCharacters: Constants.maxWindowTitleCharacters)),
            activeAccessibilityText: nonEmpty(limited(accessibilityText, maxCharacters: Constants.maxAccessibilityCharacters)),
            clipboardText: nonEmpty(clipboard),
            activeWindowOCRText: nonEmpty(ocrText)
        )
    }

    public func makePostProcessingContext(from snapshot: ContextAwarenessSnapshot) -> String? {
        guard snapshot.hasContent else { return nil }

        var lines: [String] = []
        lines.append("CONTEXT_METADATA")

        if let activeAppName = snapshot.activeAppName {
            lines.append("- Active app: \(activeAppName)")
        }

        if let activeWindowTitle = snapshot.activeWindowTitle {
            lines.append("- Active window title: \(activeWindowTitle)")
        }

        if let activeAccessibilityText = snapshot.activeAccessibilityText {
            lines.append("- Focused UI text (Accessibility):")
            lines.append(activeAccessibilityText)
        }

        if let clipboardText = snapshot.clipboardText {
            lines.append("- Clipboard text:")
            lines.append(clipboardText)
        }

        if let activeWindowOCRText = snapshot.activeWindowOCRText {
            lines.append("- Active window visible text (OCR):")
            lines.append(activeWindowOCRText)
        }

        return lines.joined(separator: "\n")
    }

    private func focusedWindowTitle(for app: NSRunningApplication?) -> String? {
        guard let app else { return nil }
        guard AccessibilityPermissionService.isTrusted() else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        let focusedWindowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard focusedWindowResult == .success, let focusedWindow else {
            return nil
        }

        guard CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() else {
            return nil
        }
        let windowElement = unsafeBitCast(focusedWindow, to: AXUIElement.self)

        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            windowElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        guard titleResult == .success else { return nil }
        return titleValue as? String
    }

    private func focusedElementText(for app: NSRunningApplication?) -> String? {
        guard let app else { return nil }
        guard AccessibilityPermissionService.isTrusted() else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElementRef: CFTypeRef?
        let focusedElementResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard focusedElementResult == .success, let focusedElementRef else { return nil }
        guard CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else { return nil }
        let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement.self)

        if let selectedText = readAXStringAttribute(focusedElement, attribute: kAXSelectedTextAttribute as String) {
            return selectedText
        }

        if let valueText = readAXStringAttribute(focusedElement, attribute: kAXValueAttribute as String) {
            return valueText
        }

        if let titleText = readAXStringAttribute(focusedElement, attribute: kAXTitleAttribute as String) {
            return titleText
        }

        if let descriptionText = readAXStringAttribute(focusedElement, attribute: kAXDescriptionAttribute as String) {
            return descriptionText
        }

        return nil
    }

    private func readClipboardText() -> String? {
        guard let value = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }

        if value.count <= Constants.maxClipboardCharacters {
            return value
        }

        let maxEndIndex = value.index(value.startIndex, offsetBy: Constants.maxClipboardCharacters)
        return String(value[..<maxEndIndex])
    }

    private func readAXStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else { return nil }

        if let stringValue = value as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let attributedString = value as? NSAttributedString {
            let trimmed = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    private func readActiveWindowOCRText(for app: NSRunningApplication?) -> String? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        guard let app else { return nil }
        guard let windowID = frontmostWindowID(for: app.processIdentifier) else { return nil }

        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            return nil
        }

        return recognizedText(from: image)
    }

    private func frontmostWindowID(for processIdentifier: pid_t) -> CGWindowID? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == processIdentifier
            else {
                continue
            }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }

            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            if alpha <= 0 { continue }

            if let idNumber = info[kCGWindowNumber as String] as? NSNumber {
                return CGWindowID(idNumber.uint32Value)
            }
        }

        return nil
    }

    private func recognizedText(from image: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let observations = request.results ?? []
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return nil }
        if text.count <= Constants.maxOCRCharacters {
            return text
        }

        let maxEndIndex = text.index(text.startIndex, offsetBy: Constants.maxOCRCharacters)
        return String(text[..<maxEndIndex])
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private func limited(_ value: String?, maxCharacters: Int) -> String? {
        guard let value else { return nil }
        guard value.count > maxCharacters else { return value }

        let endIndex = value.index(value.startIndex, offsetBy: maxCharacters)
        return String(value[..<endIndex])
    }

    private func normalizedExcludedBundleIDs(_ values: [String]) -> Set<String> {
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return Set(normalized.prefix(Constants.maxExcludedBundleIDs))
    }

    private func isSensitiveApp(
        _ app: NSRunningApplication?,
        customExcludedBundleIDs: Set<String>
    ) -> Bool {
        guard let bundleID = app?.bundleIdentifier?.lowercased() else { return false }
        return defaultSensitiveBundleIDs.contains(bundleID) || customExcludedBundleIDs.contains(bundleID)
    }

    private func redactSensitiveContent(_ value: String?) -> String? {
        guard let value else { return nil }
        var output = value

        for pattern in redactionOrder {
            guard let regex = compiledRedactionRegexes[pattern],
                  let replacement = replacementByPattern[pattern]
            else {
                continue
            }

            let fullRange = NSRange(output.startIndex..<output.endIndex, in: output)

            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: fullRange,
                withTemplate: replacement
            )
        }

        return output
    }
}
