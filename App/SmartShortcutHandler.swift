
import Foundation
import AppKit

/// A reusable handler for smart shortcut logic (Toggle, Hold, Double Tap).
/// This class encapsulates the state and timing logic to determine how a shortcut
/// should be interpreted based on the user's configuration.
@MainActor
final class SmartShortcutHandler {
    
    // MARK: - Types
    
    enum Action {
        case startRecording
        case stopRecording
    }
    
    // MARK: - Properties
    
    private var isPresetPressed = false
    private var pressStartTime: Date?
    private var wasRecordingAtPress = false
    private var startedRecording = false
    
    // Double Tap State
    private var lastTapTime: Date?
    private var lastTapWasRecording = false
    
    // MARK: - Configuration
    
    private let holdThreshold: TimeInterval
    private let doubleTapInterval: TimeInterval
    
    // MARK: - Callbacks
    
    private let actionHandler: (Action) -> Void
    private let isRecordingProvider: () -> Bool
    
    // MARK: - Initialization
    
    init(
        holdThreshold: TimeInterval = 0.35,
        doubleTapInterval: TimeInterval = 0.75, // Default to the fixed 0.75s
        isRecordingProvider: @escaping () -> Bool,
        actionHandler: @escaping (Action) -> Void
    ) {
        self.holdThreshold = holdThreshold
        self.doubleTapInterval = doubleTapInterval
        self.isRecordingProvider = isRecordingProvider
        self.actionHandler = actionHandler
    }
    
    // MARK: - Public API
    
    func reset() {
        isPresetPressed = false
        pressStartTime = nil
        wasRecordingAtPress = false
        startedRecording = false
        lastTapTime = nil
        lastTapWasRecording = false
    }
    
    func handleShortcutDown(activationMode: ShortcutActivationMode) {
        switch activationMode {
        case .toggle:
            toggleRecording()
        case .hold:
            handleHoldDown()
        case .holdOrToggle:
            handleHoldOrToggleDown()
        case .doubleTap:
            break // Handled on Up
        }
    }
    
    func handleShortcutUp(activationMode: ShortcutActivationMode) {
        switch activationMode {
        case .hold:
            handleHoldUp()
        case .holdOrToggle:
            handleHoldOrToggleUp()
        case .doubleTap:
            handleDoubleTapUp()
        case .toggle:
            break // Handled on Down
        }
    }
    
    func handleModifierChange(isActive: Bool) {
        if isActive, !isPresetPressed {
            isPresetPressed = true
            // We need to know the current activation mode to decide what to do. 
            // Since this method doesn't take it, the caller should trigger the 'Down' 
            // action if appropriate.
            // *Design Decision*: This helper tracks the state, but the caller 
            // essentially drives the 'Down'/'Up' calls based on this state change.
            // For now, let's assume the caller handles the async Task dispatch 
            // and calls handleShortcutDown.
        } else if !isActive, isPresetPressed {
            isPresetPressed = false
            // Caller handles 'Up'
        }
    }
    
    // MARK: - Private Logic
    
    private func toggleRecording() {
        if isRecordingProvider() {
            actionHandler(.stopRecording)
        } else {
            actionHandler(.startRecording)
        }
    }
    
    private func handleHoldDown() {
        pressStartTime = Date()
        wasRecordingAtPress = isRecordingProvider()
        
        if !isRecordingProvider() {
            startedRecording = true
            actionHandler(.startRecording)
        } else {
            startedRecording = false
        }
    }
    
    private func handleHoldUp() {
        if startedRecording {
            actionHandler(.stopRecording)
        }
        resetHoldState()
    }
    
    private func handleHoldOrToggleDown() {
        pressStartTime = Date()
        wasRecordingAtPress = isRecordingProvider()
        
        if isRecordingProvider() {
            actionHandler(.stopRecording)
            startedRecording = false
        } else {
            startedRecording = true
            actionHandler(.startRecording)
        }
    }
    
    private func handleHoldOrToggleUp() {
        guard let startTime = pressStartTime else { return }
        
        if !wasRecordingAtPress {
            let heldDuration = Date().timeIntervalSince(startTime)
            if heldDuration >= holdThreshold, startedRecording {
                actionHandler(.stopRecording)
            }
        }
        resetHoldState()
    }
    
    private func handleDoubleTapUp() {
        let now = Date()
        let isRecording = isRecordingProvider()
        
        if let lastTapTime = lastTapTime,
           now.timeIntervalSince(lastTapTime) <= doubleTapInterval,
           lastTapWasRecording == isRecording
        {
            self.lastTapTime = nil
            self.lastTapWasRecording = false
            toggleRecording()
        } else {
            self.lastTapTime = now
            self.lastTapWasRecording = isRecording
        }
    }
    
    private func resetHoldState() {
        pressStartTime = nil
        wasRecordingAtPress = false
        startedRecording = false
    }
}
