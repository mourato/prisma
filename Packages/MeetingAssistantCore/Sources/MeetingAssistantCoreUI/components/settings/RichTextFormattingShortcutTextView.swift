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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawTaskMarkers(in: dirtyRect)
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

    private func drawTaskMarkers(in dirtyRect: NSRect) {
        guard let textStorage,
              let textContainer,
              let layoutManager,
              textStorage.length > 0
        else {
            return
        }

        let expandedDirtyRect = dirtyRect.insetBy(dx: -8, dy: -8)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: expandedDirtyRect, in: textContainer)
        if glyphRange.length == 0 { return }

        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let accentColor = NSColor.controlAccentColor
        let fallbackLineHeight = layoutManager.defaultLineHeight(for: font ?? NSFont.systemFont(ofSize: 14))

        textStorage.enumerateAttribute(.meetingNotesTaskMarkerState, in: characterRange, options: []) { value, range, _ in
            guard let rawValue = value as? Int,
                  let markerState = MeetingNotesTaskMarkerState(rawValue: rawValue),
                  range.length > 0
            else {
                return
            }

            let markerCharacterRange = NSRange(location: range.location, length: 1)
            let markerGlyphRange = layoutManager.glyphRange(forCharacterRange: markerCharacterRange, actualCharacterRange: nil)
            if markerGlyphRange.length == 0 { return }

            let glyphRect = layoutManager.boundingRect(forGlyphRange: markerGlyphRange, in: textContainer)
            let lineHeight = max(fallbackLineHeight, glyphRect.height)
            let markerSize = max(12, min(18, round(lineHeight * 0.78)))
            let markerRect = NSRect(
                x: glyphRect.minX + textContainerInset.width + 0.5,
                y: glyphRect.midY + textContainerInset.height - (markerSize / 2),
                width: markerSize,
                height: markerSize
            )

            MeetingNotesTaskCheckmarkAdornment.draw(in: markerRect, state: markerState, accentColor: accentColor)
        }
    }
}
