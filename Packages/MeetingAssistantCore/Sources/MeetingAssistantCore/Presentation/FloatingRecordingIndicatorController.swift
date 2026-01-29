import AppKit
import Combine
import SwiftUI

/// Controller that manages the floating recording indicator window.
/// Uses NSPanel to create a non-activating floating overlay.
@MainActor
public final class FloatingRecordingIndicatorController: ObservableObject {
    // MARK: - Properties

    private var panel: NSPanel?
    private let audioMonitor: AudioLevelMonitor
    private let settingsStore: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    /// Whether the indicator is currently visible.
    @Published public private(set) var isVisible = false

    // MARK: - Configuration

    private enum Constants {
        static let panelWidth: CGFloat = 220
        static let panelHeightClassic: CGFloat = 44
        static let panelHeightMini: CGFloat = 32
        static let screenPadding: CGFloat = 20
    }

    // MARK: - Initialization

    /// Creates a new floating recording indicator controller.
    /// - Parameters:
    ///   - audioMonitor: The audio monitor to use for waveform data.
    ///   - settingsStore: The settings store for configuration.
    public init(
        audioMonitor: AudioLevelMonitor = AudioLevelMonitor(),
        settingsStore: AppSettingsStore = .shared
    ) {
        self.audioMonitor = audioMonitor
        self.settingsStore = settingsStore
        setupBindings()
    }

    // MARK: - Public API

    /// Show the floating indicator.
    /// Automatically reads style and position from settings.
    public func show() {
        guard settingsStore.recordingIndicatorEnabled else { return }
        guard settingsStore.recordingIndicatorStyle != .none else { return }
        guard panel == nil else { return }

        // Start monitoring audio levels
        audioMonitor.startMonitoring()

        // Create the panel
        let panelHeight = panelHeight(for: settingsStore.recordingIndicatorStyle)
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: Constants.panelWidth,
            height: panelHeight
        )

        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true

        // Set content view
        let indicatorView = FloatingRecordingIndicatorView(
            audioMonitor: audioMonitor,
            style: settingsStore.recordingIndicatorStyle
        )
        panel.contentView = NSHostingView(rootView: indicatorView)

        // Position the panel
        positionPanel(panel, at: settingsStore.recordingIndicatorPosition)

        // Show with fade-in animation
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        isVisible = true
    }

    /// Hide the floating indicator.
    public func hide() {
        guard let panel else { return }

        // Stop monitoring audio levels
        audioMonitor.stopMonitoring()

        // Fade out animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.close()
                self?.panel = nil
            }
        }

        isVisible = false
    }

    /// Update indicator position without recreating the panel.
    public func updatePosition() {
        guard let panel else { return }
        positionPanel(panel, at: settingsStore.recordingIndicatorPosition)
    }

    // MARK: - Private Helpers

    private func setupBindings() {
        // Observe position changes
        settingsStore.$recordingIndicatorPosition
            .dropFirst()
            .sink { [weak self] _ in
                self?.updatePosition()
            }
            .store(in: &cancellables)

        // Observe style changes (need to recreate panel)
        settingsStore.$recordingIndicatorStyle
            .dropFirst()
            .sink { [weak self] newStyle in
                guard let self, isVisible else { return }
                // Recreate panel with new style
                hide()
                if newStyle != .none {
                    show()
                }
            }
            .store(in: &cancellables)
    }

    private func panelHeight(for style: RecordingIndicatorStyle) -> CGFloat {
        switch style {
        case .classic:
            Constants.panelHeightClassic
        case .mini:
            Constants.panelHeightMini
        case .none:
            0
        }
    }

    private func positionPanel(_ panel: NSPanel, at position: RecordingIndicatorPosition) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        // Center horizontally
        let x = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2

        // Position vertically based on setting
        let y: CGFloat = switch position {
        case .top:
            screenFrame.origin.y + screenFrame.height - panelSize.height - Constants.screenPadding
        case .bottom:
            screenFrame.origin.y + Constants.screenPadding
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
