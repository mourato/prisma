import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AssistantRaycastIntegrationServiceTests: XCTestCase {
    func testValidateDeepLink_WithRaycastScheme_ReturnsValid() {
        let service = makeService()

        let result = service.validateDeepLink("raycast://ai-commands/ask-ai")

        XCTAssertEqual(result, .valid)
    }

    func testValidateDeepLink_WithInvalidScheme_ReturnsInvalid() {
        let service = makeService()

        let result = service.validateDeepLink("https://raycast.com")

        XCTAssertEqual(result, .invalid)
    }

    func testDispatch_WithValidCommand_OpensDeepLinkWithFallbackText() throws {
        var openedURLs: [URL] = []
        let service = makeService(
            openURL: { url in
                openedURLs.append(url)
                return true
            }
        )

        let result = try service.dispatch(
            command: "hello world",
            baseDeepLink: "raycast://ai-commands/ask-ai"
        )

        XCTAssertEqual(result, .openedDeepLink)
        XCTAssertEqual(openedURLs.count, 1)

        let components = try XCTUnwrap(URLComponents(url: openedURLs[0], resolvingAgainstBaseURL: false))
        let fallbackText = components.queryItems?.first(where: { $0.name == "fallbackText" })?.value
        XCTAssertEqual(fallbackText, "hello world")
    }

    func testDispatch_WithExistingFallbackText_ReplacesOldValue() throws {
        var openedURL: URL?
        let service = makeService(
            openURL: { url in
                openedURL = url
                return true
            }
        )

        let result = try service.dispatch(
            command: "new value",
            baseDeepLink: "raycast://ai-commands/ask-ai?fallbackText=old"
        )

        XCTAssertEqual(result, .openedDeepLink)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(openedURL), resolvingAgainstBaseURL: false))
        let fallbackValues = components.queryItems?
            .filter { $0.name == "fallbackText" }
            .compactMap { $0.value } ?? []
        XCTAssertEqual(fallbackValues, ["new value"])
    }

    func testDispatch_WithInvalidDeepLink_ThrowsInvalidDeepLinkError() {
        let service = makeService()

        XCTAssertThrowsError(
            try service.dispatch(command: "test", baseDeepLink: "invalid-link")
        ) { error in
            XCTAssertEqual(error as? AssistantIntegrationDispatchError, .invalidDeepLink)
        }
    }

    func testDispatch_WhenURLExceedsLimit_UsesClipboardFallback() throws {
        var openedURLs: [URL] = []
        var copiedText: String?
        let service = makeService(
            openURL: { url in
                openedURLs.append(url)
                return true
            },
            copyToClipboard: { text in
                copiedText = text
            },
            maxDeepLinkLength: 40
        )

        let result = try service.dispatch(
            command: String(repeating: "x", count: 120),
            baseDeepLink: "raycast://ai-commands/ask-ai"
        )

        XCTAssertEqual(result, .openedWithClipboardFallback)
        XCTAssertEqual(copiedText, String(repeating: "x", count: 120))
        XCTAssertEqual(openedURLs.count, 1)

        let components = try XCTUnwrap(URLComponents(url: openedURLs[0], resolvingAgainstBaseURL: false))
        let fallbackText = components.queryItems?.first(where: { $0.name == "fallbackText" })?.value
        XCTAssertNil(fallbackText)
    }

    private func makeService(
        openURL: @escaping (URL) -> Bool = { _ in true },
        copyToClipboard: @escaping (String) -> Void = { _ in },
        maxDeepLinkLength: Int = 3_800
    ) -> AssistantRaycastIntegrationService {
        AssistantRaycastIntegrationService(
            openURL: openURL,
            copyToClipboard: copyToClipboard,
            maxDeepLinkLength: maxDeepLinkLength
        )
    }
}
