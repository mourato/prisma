import AppKit
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// Controller that manages a colored border overlay around the active screen
/// to provide visual feedback when the Assistant mode is active.
@MainActor
public final class AssistantScreenBorderController {
    // MARK: - Properties

    private var borderWindow: NSWindow?
    private let settingsStore: AppSettingsStore

    /// Whether the border is currently visible.
    public private(set) var isVisible = false

    // MARK: - Configuration

    private enum Constants {
        static let borderWidth: CGFloat = 10
        static let glowRadius: CGFloat = 20
        static let animationDuration: TimeInterval = 0.2
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Initialization

    public init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore
    }

    deinit {
        borderWindow = nil
    }

    // MARK: - Public API

    /// Show the border around the active screen using configured color and style.
    public func show() {
        guard !isVisible else { return }

        if isRunningTests {
            isVisible = true
            return
        }

        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame

        let window = makeOrReuseWindow(frame: screenFrame)

        // Create the border view using SwiftUI with current settings
        let borderColor = Color(settingsStore.assistantBorderColor.nsColor)
        let borderStyle = settingsStore.assistantBorderStyle

        let borderView = AssistantScreenBorderView(
            borderWidth: Constants.borderWidth,
            glowRadius: Constants.glowRadius,
            borderColor: borderColor,
            style: borderStyle
        )
        window.contentView = NSHostingView(rootView: borderView)

        if isRunningTests {
            window.alphaValue = 1
            window.orderFront(nil)
        } else {
            window.alphaValue = 0
            window.orderFront(nil)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = Constants.animationDuration
                window.animator().alphaValue = 1
            }
        }

        isVisible = true
    }

    /// Hide the border overlay.
    public func hide() {
        if isRunningTests {
            isVisible = false
            return
        }

        guard let window = borderWindow else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            window.animator().alphaValue = 0
        } completionHandler: { [weak window] in
            Task { @MainActor in
                window?.orderOut(nil)
                window?.alphaValue = 1
            }
        }

        isVisible = false
    }

    private func makeOrReuseWindow(frame: NSRect) -> NSWindow {
        if let borderWindow {
            borderWindow.setFrame(frame, display: false)
            return borderWindow
        }

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        borderWindow = window
        return window
    }
}

// MARK: - Border View

/// SwiftUI view that renders a border or glow effect around the entire screen.
private struct AssistantScreenBorderView: View {
    let borderWidth: CGFloat
    let glowRadius: CGFloat
    let borderColor: Color
    let style: AssistantBorderStyle

    var body: some View {
        GeometryReader { geometry in
            switch style {
            case .stroke:
                strokeBorder(size: geometry.size)
            case .glow:
                glowBorder(size: geometry.size)
            }
        }
        .ignoresSafeArea()
    }

    /// Renders a solid stroke border around the screen.
    private func strokeBorder(size: CGSize) -> some View {
        Rectangle()
            .stroke(borderColor, lineWidth: borderWidth)
            .frame(width: size.width, height: size.height)
    }

    /// Renders an inner glow effect (equivalent to CSS box-shadow: inset).
    private func glowBorder(size: CGSize) -> some View {
        ZStack {
            // Multiple layered rectangles to create the glow effect
            ForEach(0..<3, id: \.self) { layer in
                Rectangle()
                    .stroke(
                        borderColor.opacity(0.6 - Double(layer) * 0.15),
                        lineWidth: borderWidth + CGFloat(layer) * 4
                    )
                    .blur(radius: CGFloat(layer) * 6 + 2)
            }

            // Core bright border
            Rectangle()
                .stroke(borderColor, lineWidth: borderWidth / 2)
                .blur(radius: 1)
        }
        .frame(width: size.width, height: size.height)
    }
}

#Preview("Assistant Border Stroke") {
    AssistantScreenBorderView(
        borderWidth: 10,
        glowRadius: 20,
        borderColor: .orange,
        style: .stroke
    )
    .frame(width: 500, height: 320)
    .background(Color.black.opacity(0.85))
}

#Preview("Assistant Border Glow") {
    AssistantScreenBorderView(
        borderWidth: 10,
        glowRadius: 20,
        borderColor: .green,
        style: .glow
    )
    .frame(width: 500, height: 320)
    .background(Color.black.opacity(0.85))
}
