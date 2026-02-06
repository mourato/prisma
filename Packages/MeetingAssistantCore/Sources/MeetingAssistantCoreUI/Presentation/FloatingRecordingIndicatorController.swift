import AppKit
import Combine
import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// Mode for the floating indicator.
public enum FloatingRecordingIndicatorMode: Sendable {
    case recording
    case processing
    case error(message: String)
}

/// Controller that manages the floating recording indicator window.
/// Uses NSPanel to create a non-activating floating overlay.
@MainActor
public final class FloatingRecordingIndicatorController: ObservableObject {
    // MARK: - Properties

    private var panel: NSPanel?
    private let audioMonitor: AudioLevelMonitor
    private let settingsStore: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var currentMode: FloatingRecordingIndicatorMode = .recording
    private var meetingType: MeetingType?

    /// Whether the indicator is currently visible.
    @Published public private(set) var isVisible = false

    // MARK: - Configuration

    private enum Constants {
        static let panelWidth: CGFloat = MeetingAssistantDesignSystem.Layout.recordingIndicatorPanelWidth
        static let panelHeightClassic: CGFloat = MeetingAssistantDesignSystem.Layout.controlHeight
        static let panelHeightMini: CGFloat = MeetingAssistantDesignSystem.Layout.controlHeight
        static let screenPadding: CGFloat = 40
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
    /// - Parameter mode: Whether to present recording or processing visuals.
    /// - Parameter type: The type of meeting being recorded.
    public func show(mode: FloatingRecordingIndicatorMode = .recording, type: MeetingType? = nil) {
        guard shouldShowIndicator(for: mode) else { return }
        currentMode = mode
        meetingType = type

        let shouldCreatePanel = panel == nil

        // Create the panel
        let panelHeight = panelHeight(for: settingsStore.recordingIndicatorStyle, mode: mode)
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: Constants.panelWidth,
            height: panelHeight
        )

        let panel = panel ?? NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        if shouldCreatePanel {
            panel.level = .screenSaver
            panel.ignoresMouseEvents = false
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovableByWindowBackground = true

            self.panel = panel
        }

        updateMode(mode)
        updateContent()

        // Position the panel
        positionPanel(panel, at: settingsStore.recordingIndicatorPosition)

        if shouldCreatePanel {
            // Show with fade-in animation
            panel.alphaValue = 0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().alphaValue = 1
            }
        }

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

    /// Update the floating indicator mode without recreating the panel.
    public func update(mode: FloatingRecordingIndicatorMode) {
        guard isVisible else { return }
        updateMode(mode)
        updateContent()
    }

    public func showError(_ message: String, autoHideAfter delay: TimeInterval = 3.0) {
        show(mode: .error(message: message))
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.hide()
        }
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
                    show(mode: currentMode)
                }
            }
            .store(in: &cancellables)
    }

    private func updateContent() {
        guard let panel else { return }
        let indicatorView = FloatingRecordingIndicatorView(
            audioMonitor: audioMonitor,
            style: settingsStore.recordingIndicatorStyle,
            mode: currentMode,
            meetingType: meetingType,
            onStop: {
                Task { @MainActor in
                    await RecordingManager.shared.stopRecording()
                }
            },
            onCancel: {
                Task { @MainActor in
                    await RecordingManager.shared.cancelRecording()
                }
            }
        )
        panel.contentView = NSHostingView(rootView: indicatorView)
    }

    private func updateMode(_ mode: FloatingRecordingIndicatorMode) {
        currentMode = mode
        switch mode {
        case .recording:
            audioMonitor.stopMonitoring()
            audioMonitor.startMonitoring()
        case .processing:
            audioMonitor.stopMonitoring()
        case .error:
            audioMonitor.stopMonitoring()
        }
    }

    private func panelHeight(
        for style: RecordingIndicatorStyle,
        mode: FloatingRecordingIndicatorMode
    ) -> CGFloat {
        switch mode {
        case .error:
            Constants.panelHeightClassic
        case .recording, .processing:
            switch style {
            case .classic:
                Constants.panelHeightClassic
            case .mini:
                Constants.panelHeightMini
            case .none:
                Constants.panelHeightMini
            }
        }
    }

    private func shouldShowIndicator(for mode: FloatingRecordingIndicatorMode) -> Bool {
        switch mode {
        case .error:
            true
        case .recording, .processing:
            settingsStore.recordingIndicatorEnabled && settingsStore.recordingIndicatorStyle != .none
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
