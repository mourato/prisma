import AppKit
@preconcurrency import ApplicationServices
import Foundation
import MeetingAssistantCoreDomain

@MainActor
public final class AXTextContextProvider: TextContextProvider {
    private let textMarkerRangeAttribute: CFString = "AXTextMarkerRange" as CFString
    private let activeAppProvider: ActiveAppContextProvider
    private let exclusionPolicy: TextContextExclusionPolicy
    private let markdownConverter: RichTextMarkdownConverter
    private let customExcludedBundleIDs: [String]

    public init(
        activeAppProvider: ActiveAppContextProvider = NSWorkspaceActiveAppContextProvider(),
        exclusionPolicy: TextContextExclusionPolicy = TextContextExclusionPolicy(),
        markdownConverter: RichTextMarkdownConverter = RichTextMarkdownConverter(),
        customExcludedBundleIDs: [String] = []
    ) {
        self.activeAppProvider = activeAppProvider
        self.exclusionPolicy = exclusionPolicy
        self.markdownConverter = markdownConverter
        self.customExcludedBundleIDs = customExcludedBundleIDs
    }

    public func fetchTextContext() async throws -> TextContextSnapshot {
        guard AccessibilityPermissionService.isTrusted() else {
            throw ContextAcquisitionError.permissionDenied
        }

        guard let appContext = try await activeAppProvider.fetchActiveAppContext() else {
            throw ContextAcquisitionError.noActiveApp
        }

        if exclusionPolicy.isExcluded(
            bundleIdentifier: appContext.bundleIdentifier,
            customExcludedBundleIDs: customExcludedBundleIDs
        ) {
            throw ContextAcquisitionError.excludedApp
        }

        let focusedElement = try focusedElement(for: appContext.processIdentifier)

        if let fullAttributed = readTextMarkerRangeText(from: focusedElement) {
            let text = formattedText(from: fullAttributed)
            return TextContextSnapshot(
                text: text,
                source: .accessibility,
                appContext: appContext
            )
        }

        if let visibleAttributed = readVisibleText(from: focusedElement) {
            let text = formattedText(from: visibleAttributed)
            return TextContextSnapshot(
                text: text,
                source: .visibleOnly,
                appContext: appContext
            )
        }

        throw ContextAcquisitionError.accessibilityUnsupported
    }

    private func focusedElement(for processIdentifier: Int) throws -> AXUIElement {
        let appElement = AXUIElementCreateApplication(pid_t(processIdentifier))
        var focusedElementRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard result == .success else {
            if result == .attributeUnsupported {
                throw ContextAcquisitionError.accessibilityUnsupported
            }
            throw ContextAcquisitionError.noFocusedElement
        }

        guard let focusedElementRef,
              CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID()
        else {
            throw ContextAcquisitionError.accessibilityUnsupported
        }

        return unsafeDowncast(focusedElementRef, to: AXUIElement.self)
    }

    private func readTextMarkerRangeText(from element: AXUIElement) -> NSAttributedString? {
        var markerRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            textMarkerRangeAttribute,
            &markerRangeRef
        )

        guard rangeResult == .success, let markerRangeRef else { return nil }

        var attributedTextRef: CFTypeRef?
        let paramResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXAttributedStringForRangeParameterizedAttribute as CFString,
            markerRangeRef,
            &attributedTextRef
        )

        guard paramResult == .success else { return nil }
        return attributedTextRef as? NSAttributedString
    }

    private func readVisibleText(from element: AXUIElement) -> NSAttributedString? {
        var visibleRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXVisibleCharacterRangeAttribute as CFString,
            &visibleRangeRef
        )

        guard rangeResult == .success, let visibleRangeRef else { return nil }

        var attributedTextRef: CFTypeRef?
        let paramResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXAttributedStringForRangeParameterizedAttribute as CFString,
            visibleRangeRef,
            &attributedTextRef
        )

        guard paramResult == .success else { return nil }
        return attributedTextRef as? NSAttributedString
    }

    private func formattedText(from attributedText: NSAttributedString) -> String {
        let converted = markdownConverter.convertIfRichText(attributedText)
        let rawText = converted ?? attributedText.string
        return normalizeLineBreaks(rawText)
    }

    private func normalizeLineBreaks(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
