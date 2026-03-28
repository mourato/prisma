import AppKit
import MeetingAssistantCoreCommon
import SwiftUI

@MainActor
public final class MeetingNotesFloatingPanelController {
    static let maximumScreenHeightRatio: CGFloat = 0.9

    private var panel: NSPanel?
    private var hostingView: NSHostingView<MeetingNotesFloatingPanelView>?
    private var panelDelegate: PanelDelegate?

    public init() {}

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    public func show(
        content: MeetingNotesContent,
        onTextChange: @escaping (MeetingNotesContent) -> Void,
        onClose: @escaping () -> Void
    ) {
        let panel = ensurePanel(onClose: onClose)
        let rootView = MeetingNotesFloatingPanelView(
            content: content,
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

        enforcePanelHeightLimit(panel)
        panel.level = .floating
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: false)
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    private func ensurePanel(onClose: @escaping () -> Void) -> NSPanel {
        if let panel {
            panelDelegate?.onClose = onClose
            enforcePanelHeightLimit(panel)
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
        let delegate = PanelDelegate(
            onClose: onClose,
            onGeometryChange: { [weak self, weak panel] in
                guard let self, let panel else { return }
                enforcePanelHeightLimit(panel)
            }
        )
        panel.delegate = delegate
        panelDelegate = delegate
        panel.center()

        self.panel = panel
        enforcePanelHeightLimit(panel)
        return panel
    }

    private func enforcePanelHeightLimit(_ panel: NSPanel) {
        guard let visibleFrame = targetVisibleFrame(for: panel) else { return }
        let maxHeight = max(
            panel.minSize.height,
            floor(visibleFrame.height * Self.maximumScreenHeightRatio)
        )

        let currentMaxSize = panel.maxSize
        panel.maxSize = NSSize(width: currentMaxSize.width, height: maxHeight)

        let clampedFrame = Self.clampedPanelFrame(
            panel.frame,
            within: visibleFrame,
            maxHeight: maxHeight
        )
        guard !panel.frame.equalTo(clampedFrame) else {
            return
        }

        panel.setFrame(clampedFrame, display: false)
    }

    private func targetVisibleFrame(for panel: NSPanel) -> NSRect? {
        if let screenFrame = panel.screen?.visibleFrame {
            return screenFrame
        }
        if let mainScreenFrame = NSScreen.main?.visibleFrame {
            return mainScreenFrame
        }
        return NSScreen.screens.first?.visibleFrame
    }

    static func clampedPanelFrame(
        _ frame: NSRect,
        within visibleFrame: NSRect,
        maxHeight: CGFloat
    ) -> NSRect {
        let clampedHeight = min(frame.height, maxHeight)
        let maxOriginY = visibleFrame.maxY - clampedHeight
        let clampedOriginY = min(max(frame.origin.y, visibleFrame.minY), maxOriginY)
        return NSRect(
            x: frame.origin.x,
            y: clampedOriginY,
            width: frame.width,
            height: clampedHeight
        )
    }
}

private final class PanelDelegate: NSObject, NSWindowDelegate {
    var onClose: () -> Void
    private let onGeometryChange: () -> Void

    init(
        onClose: @escaping () -> Void,
        onGeometryChange: @escaping () -> Void
    ) {
        self.onClose = onClose
        self.onGeometryChange = onGeometryChange
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        onGeometryChange()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        onGeometryChange()
    }
}

private struct MeetingNotesFloatingPanelView: View {
    @State private var content: MeetingNotesContent
    let onTextChange: (MeetingNotesContent) -> Void

    init(
        content: MeetingNotesContent,
        onTextChange: @escaping (MeetingNotesContent) -> Void
    ) {
        _content = State(initialValue: content)
        self.onTextChange = onTextChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("recording_indicator.meeting_notes.help".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            MeetingNotesRichTextEditor(content: $content)
        }
        .padding(12)
        .onChange(of: content) { _, newValue in
            onTextChange(newValue)
        }
    }
}

#Preview("Meeting Notes Floating Panel") {
    MeetingNotesFloatingPanelView(
        content: MeetingNotesContent(plainText: "- Revisar backlog\n- Alinhar owners para Q2"),
        onTextChange: { _ in }
    )
    .frame(width: 620, height: 300)
}
