import AppKit
import MeetingAssistantCoreCommon
import SwiftUI

struct MeetingNotesMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    private let formatter = MeetingNotesMarkdownFormatter()

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.usesFindBar = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        context.coordinator.applyExternalMarkdown(text, to: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.applyExternalMarkdown(text, to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, formatter: formatter)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        private let formatter: MeetingNotesMarkdownFormatter
        private var isApplyingProgrammaticUpdate = false
        private var lastRenderedMarkdown = ""
        private var lastEmittedMarkdown = ""

        init(text: Binding<String>, formatter: MeetingNotesMarkdownFormatter) {
            _text = text
            self.formatter = formatter
        }

        func applyExternalMarkdown(_ markdown: String, to textView: NSTextView) {
            let sanitizedMarkdown = MeetingNotesMarkdownSanitizer.sanitizeForMarkdownRendering(markdown)
            guard sanitizedMarkdown != lastRenderedMarkdown else {
                return
            }

            let attributedText = formatter.attributedStringForEditing(from: sanitizedMarkdown)
            let currentSelection = textView.selectedRange()

            isApplyingProgrammaticUpdate = true
            textView.textStorage?.setAttributedString(attributedText)
            let clampedLocation = min(currentSelection.location, attributedText.length)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
            isApplyingProgrammaticUpdate = false

            lastRenderedMarkdown = sanitizedMarkdown
            lastEmittedMarkdown = sanitizedMarkdown
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView
            else {
                return
            }

            let markdown = formatter.markdownForPersistence(from: textView.attributedString())
            guard markdown != lastEmittedMarkdown else {
                return
            }

            lastEmittedMarkdown = markdown
            lastRenderedMarkdown = markdown
            text = markdown
        }
    }
}
