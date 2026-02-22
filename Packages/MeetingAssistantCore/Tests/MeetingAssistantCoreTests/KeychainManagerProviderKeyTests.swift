import XCTest
@testable import MeetingAssistantCore

final class KeychainManagerProviderKeyTests: XCTestCase {
    func testGoogleProviderMapsToDedicatedKeychainSlot() {
        XCTAssertEqual(KeychainManager.apiKeyKey(for: .google), .aiAPIKeyGoogle)
    }
}
