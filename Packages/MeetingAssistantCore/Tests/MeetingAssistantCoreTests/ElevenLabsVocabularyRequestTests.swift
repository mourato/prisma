@testable import MeetingAssistantCoreAI
import XCTest

final class ElevenLabsVocabularyRequestTests: XCTestCase {
    func testMultipartBody_IncludesRepeatedKeytermsFields() {
        let body = ElevenLabsTranscriptionClient.multipartBody(
            boundary: "Bound",
            fileData: Data("audio".utf8),
            fileName: "clip.wav",
            modelID: "scribe_v2",
            inputLanguageCode: "en",
            vocabularyKeyterms: ["SwiftUI", "Metal"],
        )
        let text = String(bytes: body, encoding: .utf8) ?? ""

        XCTAssertTrue(text.contains("name=\"keyterms\""))
        XCTAssertTrue(text.contains("SwiftUI"))
        XCTAssertTrue(text.contains("Metal"))
        XCTAssertFalse(text.contains("name=\"custom_prompt\""))
        XCTAssertFalse(text.contains("name=\"prompt\""))

        let keytermFieldCount = text.components(separatedBy: "name=\"keyterms\"").count - 1
        XCTAssertEqual(keytermFieldCount, 2)
    }

    func testMultipartBody_OmitsKeytermsWhenEmpty() {
        let body = ElevenLabsTranscriptionClient.multipartBody(
            boundary: "Bound",
            fileData: Data("audio".utf8),
            fileName: "clip.wav",
            modelID: "scribe_v2",
            inputLanguageCode: nil,
            vocabularyKeyterms: [],
        )
        let text = String(bytes: body, encoding: .utf8) ?? ""

        XCTAssertFalse(text.contains("name=\"keyterms\""))
        XCTAssertFalse(text.contains("name=\"custom_prompt\""))
    }
}
