import AppKit

final class RichTextFormattingShortcutTextView: NSTextView {
    enum FormattingShortcutAction {
        case bold
        case italic
        case unorderedList
        case orderedList
        case indent
        case outdent
    }

    var onFormattingShortcut: ((FormattingShortcutAction) -> Void)?
    var onTaskMarkerClick: ((Int) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if handleIndentationShortcut(event) {
            return
        }
        if handleFormattingShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if handleTaskMarkerClick(event) {
            return
        }
        super.mouseDown(with: event)
    }

    private func handleIndentationShortcut(_ event: NSEvent) -> Bool {
        guard event.keyCode == 48 else { return false }

        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasOnlyShiftModifier = normalizedFlags == [.shift]
        let hasNoModifiers = normalizedFlags.isEmpty

        if hasNoModifiers {
            onFormattingShortcut?(.indent)
            return true
        }

        if hasOnlyShiftModifier {
            onFormattingShortcut?(.outdent)
            return true
        }

        return false
    }

    private func handleFormattingShortcut(_ event: NSEvent) -> Bool {
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard normalizedFlags.contains(.command),
              !normalizedFlags.contains(.option),
              !normalizedFlags.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return false
        }

        switch key {
        case "b":
            onFormattingShortcut?(.bold)
            return true
        case "i":
            onFormattingShortcut?(.italic)
            return true
        case "7" where normalizedFlags.contains(.shift):
            onFormattingShortcut?(.orderedList)
            return true
        case "8" where normalizedFlags.contains(.shift):
            onFormattingShortcut?(.unorderedList)
            return true
        default:
            return false
        }
    }

    private func handleTaskMarkerClick(_ event: NSEvent) -> Bool {
        guard let onTaskMarkerClick,
              let textContainer,
              let layoutManager
        else {
            return false
        }

        let localPoint = convert(event.locationInWindow, from: nil)
        let glyphPoint = NSPoint(
            x: localPoint.x - textContainerInset.width,
            y: localPoint.y - textContainerInset.height
        )

        var fraction: CGFloat = 0
        let characterIndex = layoutManager.characterIndex(
            for: glyphPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )

        return onTaskMarkerClick(characterIndex)
    }
}
