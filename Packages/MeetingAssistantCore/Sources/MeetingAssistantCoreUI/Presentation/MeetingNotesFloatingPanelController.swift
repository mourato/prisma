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
