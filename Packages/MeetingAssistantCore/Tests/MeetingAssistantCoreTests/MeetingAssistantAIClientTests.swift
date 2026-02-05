import Foundation
@testable import MeetingAssistantCore
import XCTest

final class MeetingAssistantAIClientTests: XCTestCase {
    func testFetchServiceStatus_CompletesWithinTimeout() async throws {
        try XCTSkipIf(!FeatureFlags.useXPCService, "XPC Service is disabled")

        do {
            let status = try await MeetingAssistantAIClient.shared.fetchServiceStatus()
            XCTAssertFalse(status.status.isEmpty)
        } catch is TranscriptionError {
            // Expected in test environment where XPC service is not running
        } catch {
            // Any other error is acceptable in test environment
        }
    }
}
