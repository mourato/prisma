import Foundation

public struct AssistantShortcutLayerStateMachine: Sendable {
    public enum State: String, CaseIterable, Equatable, Sendable {
        case idle
        case armed
        case consumed
        case timedOut
        case cancelled
    }

    public enum Event: String, Equatable, Sendable {
        case leaderTapped
        case layerKeyMatched
        case timeoutElapsed
        case cancelledByEscapeOrBlur
        case disarmedExplicitly
    }

    public struct Transition: Equatable, Sendable {
        public let from: State
        public let to: State
        public let event: Event
        public let isValid: Bool

        public init(from: State, to: State, event: Event, isValid: Bool) {
            self.from = from
            self.to = to
            self.event = event
            self.isValid = isValid
        }
    }

    public private(set) var state: State

    public init(initialState: State = .idle) {
        state = initialState
    }

    @discardableResult
    public mutating func transition(on event: Event) -> Transition {
        let currentState = state
        let nextState: State?

        switch (currentState, event) {
        case (.idle, .leaderTapped),
             (.consumed, .leaderTapped),
             (.timedOut, .leaderTapped),
             (.cancelled, .leaderTapped),
             (.armed, .leaderTapped):
            nextState = .armed

        case (.armed, .layerKeyMatched):
            nextState = .consumed

        case (.armed, .timeoutElapsed):
            nextState = .timedOut

        case (.armed, .cancelledByEscapeOrBlur):
            nextState = .cancelled

        case (.idle, .disarmedExplicitly),
             (.armed, .disarmedExplicitly),
             (.consumed, .disarmedExplicitly),
             (.timedOut, .disarmedExplicitly),
             (.cancelled, .disarmedExplicitly):
            nextState = .idle

        default:
            nextState = nil
        }

        guard let nextState else {
            return Transition(
                from: currentState,
                to: currentState,
                event: event,
                isValid: false
            )
        }

        state = nextState
        return Transition(
            from: currentState,
            to: nextState,
            event: event,
            isValid: true
        )
    }
}
