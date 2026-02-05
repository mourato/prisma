import Foundation
@testable import MeetingAssistantCore
import XCTest

final class MeetingAssistantAIClientTests: XCTestCase {
    func testFetchServiceStatus_CompletesWithinTimeout() async throws {
        let expectation = expectation(description: "fetchServiceStatus completes")

        Task {
            _ = try? await MeetingAssistantAIClient.shared.fetchServiceStatus()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }
}

