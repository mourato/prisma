import Foundation

#if DEBUG
import MeetingAssistantCoreMocking
#endif

#if DEBUG
@GenerateMock
#endif
public protocol TextContextProvider: Sendable {
    func fetchTextContext() async throws -> TextContextSnapshot
}

#if DEBUG
@GenerateMock
#endif
public protocol ActiveAppContextProvider: Sendable {
    func fetchActiveAppContext() async throws -> ActiveAppContext?
}
