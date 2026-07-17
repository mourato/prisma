@testable import MeetingAssistantCoreAI
import XCTest

final class GroqVocabularyRequestTests: XCTestCase {
    func testMultipartBody_IncludesPromptWhenHintProvided() {
        let body = GroqTranscriptionClient.multipartBody(
            boundary: "Bound",
            fileData: Data("audio".utf8),
            fileName: "clip.wav",
            modelID: "whisper-large-v3-turbo",
            inputLanguageCode: "en",
            vocabularyHint: "SwiftUI, Metal",
        )
        let text = String(bytes: body, encoding: .utf8) ?? ""

        XCTAssertTrue(text.contains("name=\"prompt\""))
        XCTAssertTrue(text.contains("SwiftUI, Metal"))
        XCTAssertFalse(text.contains("name=\"keyterms\""))
    }

    func testMultipartBody_OmitsPromptWhenHintEmpty() {
        let body = GroqTranscriptionClient.multipartBody(
            boundary: "Bound",
            fileData: Data("audio".utf8),
            fileName: "clip.wav",
            modelID: "whisper-large-v3-turbo",
            inputLanguageCode: nil,
            vocabularyHint: nil,
        )
        let text = String(bytes: body, encoding: .utf8) ?? ""

        XCTAssertFalse(text.contains("name=\"prompt\""))
    }
}
