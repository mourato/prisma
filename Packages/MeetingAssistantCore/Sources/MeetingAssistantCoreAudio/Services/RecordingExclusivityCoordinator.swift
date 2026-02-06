import Foundation

public actor RecordingExclusivityCoordinator {
    public static let shared = RecordingExclusivityCoordinator()

    private var activeMode: ActiveMode?

    public enum ActiveMode: String, Sendable {
        case recording
        case assistant
    }

    private init() {}

    public func beginRecording() -> Bool {
        guard activeMode == nil else {
            return false
        }

        activeMode = .recording
        return true
    }

    public func endRecording() {
        guard activeMode == .recording else {
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
}
