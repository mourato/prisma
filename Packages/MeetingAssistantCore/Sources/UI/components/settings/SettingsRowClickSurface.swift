import AppKit
import SwiftUI

public struct SettingsRowClickSurface<Content: View>: View {
    private let onSingleClick: (() -> Void)?
    private let onDoubleClick: (() -> Void)?
    private let content: () -> Content

    public init(
        onSingleClick: (() -> Void)? = nil,
        onDoubleClick: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onSingleClick = onSingleClick
        self.onDoubleClick = onDoubleClick
        self.content = content
    }

    public var body: some View {
        content()
            .contentShape(Rectangle())
            .overlay {
                SettingsRowClickCaptureRepresentable(
                    onSingleClick: onSingleClick,
                    onDoubleClick: onDoubleClick
                )
            }
    }
}

private struct SettingsRowClickCaptureRepresentable: NSViewRepresentable {
    let onSingleClick: (() -> Void)?
    let onDoubleClick: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleClick: onSingleClick, onDoubleClick: onDoubleClick)
    }

    func makeNSView(context: Context) -> SettingsRowClickCaptureView {
        let view = SettingsRowClickCaptureView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: SettingsRowClickCaptureView, context: Context) {
        context.coordinator.onSingleClick = onSingleClick
        context.coordinator.onDoubleClick = onDoubleClick
        nsView.coordinator = context.coordinator
    }

    final class Coordinator: NSObject {
        var onSingleClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?

        init(onSingleClick: (() -> Void)?, onDoubleClick: (() -> Void)?) {
            self.onSingleClick = onSingleClick
            self.onDoubleClick = onDoubleClick
        }

        @objc func handleSingleClick() {
            onSingleClick?()
        }

        @objc func handleDoubleClick() {
            onDoubleClick?()
        }
    }
}

private final class SettingsRowClickCaptureView: NSView {
    weak var coordinator: SettingsRowClickCaptureRepresentable.Coordinator? {
        didSet {}
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let coordinator else { return }

        if event.clickCount >= 2 {
            coordinator.handleDoubleClick()
            return
        }

        coordinator.handleSingleClick()
    }
}

#Preview("Settings Row Click Surface") {
    SettingsRowClickSurface(
        onSingleClick: {},
        onDoubleClick: {},
        content: {
            Text("Example row")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary)
        }
    )
    .frame(width: 320)
    .padding()
}
