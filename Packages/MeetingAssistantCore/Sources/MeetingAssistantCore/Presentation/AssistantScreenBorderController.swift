import AppKit
import SwiftUI

/// Controller that manages a green border overlay around the active screen
/// to provide visual feedback when the Assistant mode is active.
@MainActor
public final class AssistantScreenBorderController {
    // MARK: - Properties

    private var borderWindow: NSWindow?

    /// Whether the border is currently visible.
    public private(set) var isVisible = false

    // MARK: - Configuration

    private enum Constants {
        static let borderWidth: CGFloat = 10
        static let borderColor = NSColor.systemGreen
        static let animationDuration: TimeInterval = 0.2
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Show the green border around the active screen.
    public func show() {
        guard !isVisible else { return }

        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame

        // Create a borderless, transparent window that covers the entire screen
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Configure window properties for overlay behavior
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Create the border view using SwiftUI
        let borderView = AssistantScreenBorderView(
            borderWidth: Constants.borderWidth,
            borderColor: Color(Constants.borderColor)
        )
        window.contentView = NSHostingView(rootView: borderView)

        // Store reference and show with animation
        borderWindow = window

        window.alphaValue = 0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            window.animator().alphaValue = 1
        }

        isVisible = true
    }

    /// Hide the green border overlay.
    public func hide() {
        guard let window = borderWindow else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.borderWindow?.close()
                self?.borderWindow = nil
            }
        }

        isVisible = false
    }
}

// MARK: - Border View

/// SwiftUI view that renders a border around the entire screen.
private struct AssistantScreenBorderView: View {
    let borderWidth: CGFloat
    let borderColor: Color

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .stroke(borderColor, lineWidth: borderWidth)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}
