import AppKit
import MeetingAssistantCoreCommon
import SwiftUI

@MainActor
public final class MeetingNotesFloatingPanelController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<MeetingNotesFloatingPanelView>?
    private var panelDelegate: PanelDelegate?

    public init() {}

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    public func show(
        text: String,
        onTextChange: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        let panel = ensurePanel(onClose: onClose)
        let rootView = MeetingNotesFloatingPanelView(
            text: text,
            onTextChange: onTextChange
        )

        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let host = NSHostingView(rootView: rootView)
            host.translatesAutoresizingMaskIntoConstraints = false
            panel.contentView = host
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
                host.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
                host.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
            ])
            hostingView = host
        }

        panel.level = .floating
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: false)
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    private func ensurePanel(onClose: @escaping () -> Void) -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        panel.title = "recording_indicator.meeting_notes.title".localized
        panel.minSize = NSSize(width: 320, height: 220)
        let delegate = PanelDelegate(onClose: onClose)
        panel.delegate = delegate
        panelDelegate = delegate
        panel.center()

        self.panel = panel
        return panel
    }
}

private final class PanelDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

private struct MeetingNotesFloatingPanelView: View {
    @State private var text: String
    let onTextChange: (String) -> Void

    init(
        text: String,
        onTextChange: @escaping (String) -> Void
    ) {
        _text = State(initialValue: text)
        self.onTextChange = onTextChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("recording_indicator.meeting_notes.help".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            MeetingNotesMarkdownEditor(text: $text)
        }
        .padding(12)
        .onChange(of: text) { _, newValue in
            onTextChange(newValue)
        }
    }
}

private struct MeetingNotesMarkdownEditor: NSViewRepresentable {
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
