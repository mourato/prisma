import Foundation
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class MeetingQAServiceTests: XCTestCase {
    private var originalMeetingQnAEnabled = false
    private var originalAIConfiguration = AIConfiguration.default
    private var originalEnhancementsAISelection = EnhancementsAISelection.default

    override func setUp() async throws {
        try await super.setUp()
        let settings = AppSettingsStore.shared
        originalMeetingQnAEnabled = settings.meetingQnAEnabled
        originalAIConfiguration = settings.aiConfiguration
        originalEnhancementsAISelection = settings.enhancementsAISelection

        settings.meetingQnAEnabled = true
        settings.aiConfiguration = AIConfiguration(
            provider: .openai,
            baseURL: "https://example.com/v1",
            selectedModel: "gpt-4o-mini"
        )
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "gpt-4o-mini"
        )
    }

    override func tearDown() async throws {
        let settings = AppSettingsStore.shared
        settings.meetingQnAEnabled = originalMeetingQnAEnabled
        settings.aiConfiguration = originalAIConfiguration
        settings.enhancementsAISelection = originalEnhancementsAISelection
        MockMeetingQANetworkURLProtocol.requestHandler = nil
        try await super.tearDown()
    }

    func testAskReturnsAnsweredWithEvidence() async throws {
        let session = makeMockedSession()
        MockMeetingQANetworkURLProtocol.requestHandler = { _ in
            let body = """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\\"status\\\":\\\"answered\\\",\\\"answer\\\":\\\"Launch is Friday.\\\",\\\"evidence\\\":[{\\\"speaker\\\":\\\"Ana\\\",\\\"startTime\\\":12,\\\"endTime\\\":16,\\\"excerpt\\\":\\\"Vamos lançar sexta.\\\"}]}"
                  }
                }
              ]
            }
            """
            return (
                HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(body.utf8)
            )
        }

        let service = MeetingQAService(
            settings: .shared,
            session: session,
            apiKeyProvider: { _ in "test-key" },
            sleepFunction: { _ in }
        )

        let response = try await service.ask(
            question: "When are we launching?",
            transcription: makeTranscription()
        )

        XCTAssertEqual(response.status, .answered)
        XCTAssertEqual(response.answer, "Launch is Friday.")
        XCTAssertEqual(response.evidence.count, 1)
        XCTAssertEqual(response.evidence.first?.speaker, "Ana")
    }

    func testAskReturnsNotFoundWhenAnsweredPayloadHasNoEvidence() async throws {
        let session = makeMockedSession()
        MockMeetingQANetworkURLProtocol.requestHandler = { _ in
            let body = """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\\"status\\\":\\\"answered\\\",\\\"answer\\\":\\\"This lacks evidence.\\\",\\\"evidence\\\":[]}"
                  }
                }
              ]
            }
            """
            return (
                HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(body.utf8)
            )
        }

        let service = MeetingQAService(
            settings: .shared,
            session: session,
            apiKeyProvider: { _ in "test-key" },
            sleepFunction: { _ in }
        )

        let response = try await service.ask(
            question: "What did we decide?",
            transcription: makeTranscription()
        )

        XCTAssertEqual(response.status, .notFound)
        XCTAssertTrue(response.answer.isEmpty)
        XCTAssertTrue(response.evidence.isEmpty)
    }

    func testAskRetriesOnceAfterTimeoutThenSucceeds() async throws {
        let session = makeMockedSession()
        var callCount = 0

        MockMeetingQANetworkURLProtocol.requestHandler = { _ in
            callCount += 1

            if callCount == 1 {
                throw URLError(.timedOut)
            }

            let body = """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\\"status\\\":\\\"answered\\\",\\\"answer\\\":\\\"Budget approved.\\\",\\\"evidence\\\":[{\\\"speaker\\\":\\\"João\\\",\\\"startTime\\\":30,\\\"endTime\\\":38,\\\"excerpt\\\":\\\"Fechamos o orçamento hoje.\\\"}]}"
                  }
                }
              ]
            }
            """

            return (
                HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(body.utf8)
            )
        }

        let service = MeetingQAService(
            settings: .shared,
            session: session,
            apiKeyProvider: { _ in "test-key" },
            sleepFunction: { _ in }
        )

        let response = try await service.ask(
            question: "What happened with budget?",
            transcription: makeTranscription()
        )

        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(response.status, .answered)
        XCTAssertEqual(response.answer, "Budget approved.")
    }

    func testAskWithGoogleProviderParsesGeminiPayload() async throws {
        let settings = AppSettingsStore.shared
        settings.aiConfiguration = AIConfiguration(
            provider: .google,
            baseURL: AIProvider.google.defaultBaseURL,
            selectedModel: "gemini-2.0-flash"
        )
        settings.enhancementsAISelection = EnhancementsAISelection(
            provider: .google,
            selectedModel: "gemini-2.0-flash"
        )

        let session = makeMockedSession()
        MockMeetingQANetworkURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("models/gemini-2.0-flash:generateContent") ?? false)
            XCTAssertTrue(request.url?.absoluteString.contains("key=test-key") ?? false)
            let body = """
            {
              "candidates": [
                {
                  "content": {
                    "parts": [
                      {
                        "text": "{\\\"status\\\":\\\"answered\\\",\\\"answer\\\":\\\"Launch is Friday.\\\",\\\"evidence\\\":[{\\\"speaker\\\":\\\"Ana\\\",\\\"startTime\\\":12,\\\"endTime\\\":16,\\\"excerpt\\\":\\\"Vamos lançar sexta.\\\"}]}"
                      }
                    ]
                  }
                }
              ]
            }
            """
            return (
                HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(body.utf8)
            )
        }

        let service = MeetingQAService(
            settings: .shared,
            session: session,
            apiKeyProvider: { _ in "test-key" },
            sleepFunction: { _ in }
        )

        let response = try await service.ask(
            question: "When are we launching?",
            transcription: makeTranscription()
        )

        XCTAssertEqual(response.status, .answered)
        XCTAssertEqual(response.answer, "Launch is Friday.")
    }

    private func makeMockedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockMeetingQANetworkURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeTranscription() -> Transcription {
        Transcription(
            meeting: Meeting(id: UUID(), app: .googleMeet, startTime: Date(), endTime: Date().addingTimeInterval(60)),
            segments: [
                .init(speaker: "Ana", text: "Vamos lançar sexta.", startTime: 12, endTime: 16),
                .init(speaker: "João", text: "Fechamos o orçamento hoje.", startTime: 30, endTime: 38),
            ],
            text: "Vamos lançar sexta. Fechamos o orçamento hoje.",
            rawText: "vamos lancar sexta fechamos o orçamento hoje"
        )
    }
}

private final class MockMeetingQANetworkURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
