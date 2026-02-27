import Security
import XCTest
@testable import MeetingAssistantCore

final class KeychainManagerBatchRetrievalTests: XCTestCase {
    func testMapAPIKeyItems_MapsKnownProviderAccounts() {
        let items: [[String: Any]] = [
            [
                kSecAttrAccount as String: KeychainManager.Key.aiAPIKeyOpenAI.rawValue,
                kSecValueData as String: Data("sk-openai".utf8),
            ],
            [
                kSecAttrAccount as String: KeychainManager.Key.aiAPIKeyGoogle.rawValue,
                kSecValueData as String: Data("sk-google".utf8),
            ],
        ]

        let mapped = KeychainManager.mapAPIKeyItems(items, allowedProviders: [.openai, .google, .anthropic])

        XCTAssertEqual(mapped[.openai], "sk-openai")
        XCTAssertEqual(mapped[.google], "sk-google")
        XCTAssertNil(mapped[.anthropic])
    }

    func testMapAPIKeyItems_IgnoresUnknownAccounts() {
        let items: [[String: Any]] = [
            [
                kSecAttrAccount as String: "unknown_account",
                kSecValueData as String: Data("ignored".utf8),
            ],
            [
                kSecAttrAccount as String: KeychainManager.Key.aiAPIKeyAnthropic.rawValue,
                kSecValueData as String: Data("sk-anthropic".utf8),
            ],
        ]

        let mapped = KeychainManager.mapAPIKeyItems(items, allowedProviders: [.openai, .anthropic])

        XCTAssertEqual(mapped.count, 1)
        XCTAssertEqual(mapped[.anthropic], "sk-anthropic")
        XCTAssertNil(mapped[.openai])
    }

    func testMapAPIKeyItems_ReturnsEmptyForEmptyInput() {
        let mapped = KeychainManager.mapAPIKeyItems([], allowedProviders: [.openai, .google])
        XCTAssertTrue(mapped.isEmpty)
    }
}
