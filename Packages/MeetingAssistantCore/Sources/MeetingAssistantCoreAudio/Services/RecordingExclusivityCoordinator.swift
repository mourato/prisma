import Foundation

public actor RecordingExclusivityCoordinator {
    public static let shared = RecordingExclusivityCoordinator()

    private var activeMode: ActiveMode?

    public enum ActiveMode: String, Sendable {
        case dictation
        case meeting
        case assistant
    }

    public enum RecordingMode: String, Sendable {
        case dictation
        case meeting

        var activeMode: ActiveMode {
            switch self {
            case .dictation:
                .dictation
            case .meeting:
                .meeting
            }
        }
    }

    private init() {}

    /// Backward-compatible entry point used by older tests/callers.
    public func beginRecording() -> Bool {
        beginRecording(mode: .meeting)
    }

    public func beginRecording(mode: RecordingMode) -> Bool {
        guard activeMode == nil else {
            return false
        }

        activeMode = mode.activeMode
        return true
    }

    public func endRecording() {
        guard activeMode == .dictation || activeMode == .meeting else {
            return
        }

        activeMode = nil
    }

    public func beginAssistant() -> Bool {
        guard activeMode == nil else {
            return false
        }

        activeMode = .assistant
        return true
    }

    public func endAssistant() {
        guard activeMode == .assistant else {
            return
        }

        activeMode = nil
    }

    public func activeModeSnapshot() -> ActiveMode? {
        activeMode
    }

    public func activeRecordingMode() -> RecordingMode? {
        switch activeMode {
        case .dictation:
            .dictation
        case .meeting:
            .meeting
        case .assistant, .none:
            nil
        }
    }

    public func isRecordingActive(mode: RecordingMode) -> Bool {
        activeMode == mode.activeMode
    }

    public func blockingMode(for requestedMode: ActiveMode) -> ActiveMode? {
        guard let activeMode, activeMode != requestedMode else {
            return nil
        }
        return activeMode
    }
}
