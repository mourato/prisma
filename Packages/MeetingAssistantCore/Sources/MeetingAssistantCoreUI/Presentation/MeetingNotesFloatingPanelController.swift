import AppKit
import MeetingAssistantCoreCommon
import SwiftUI
import Textual

@MainActor
public final class MeetingNotesFloatingPanelController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<MeetingNotesFloatingPanelView>?
    private var panelDelegate: PanelDelegate?
    private let editorEngineResolver: MeetingNotesEditorEngineResolver

    public init() {
        editorEngineResolver = .init()
    }

    init(editorEngineResolver: MeetingNotesEditorEngineResolver) {
        self.editorEngineResolver = editorEngineResolver
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    public func show(
        text: String,
        onTextChange: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        let panel = ensurePanel(onClose: onClose)
        let editorEngine = editorEngineResolver.resolve()
        AppLogger.info(
            "Meeting notes editor engine selected",
            category: .uiController,
            extra: ["engine": editorEngine.rawValue]
        )
        let rootView = MeetingNotesFloatingPanelView(
            text: text,
            editorEngine: editorEngine,
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
    private let editorEngine: MeetingNotesEditorEngine
    let onTextChange: (String) -> Void

    init(
        text: String,
        editorEngine: MeetingNotesEditorEngine,
        onTextChange: @escaping (String) -> Void
    ) {
        _text = State(initialValue: text)
        self.editorEngine = editorEngine
        self.onTextChange = onTextChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("recording_indicator.meeting_notes.help".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            switch editorEngine {
            case .textual:
                TextualMeetingNotesEditor(text: $text)
            case .native:
                NativeMeetingNotesEditor(text: $text)
            }
        }
        .padding(12)
        .onChange(of: text) { _, newValue in
            onTextChange(newValue)
        }
    }
}

private struct NativeMeetingNotesEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct TextualMeetingNotesEditor: View {
    @Binding var text: String

    var body: some View {
        VStack(spacing: 8) {
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))

            Divider()

            ScrollView {
                StructuredText(markdown: text)
                    .textual.textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}
