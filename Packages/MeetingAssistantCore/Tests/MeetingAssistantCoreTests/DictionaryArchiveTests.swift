@testable import MeetingAssistantCore
import XCTest

final class DictionaryArchiveTests: XCTestCase {

    // MARK: - Round-trip

    func testArchiveRoundTrip() throws {
        let terms = [
            VocabularyTerm(term: "SwiftUI", definition: "UI framework"),
            VocabularyTerm(term: "Metal", definition: "GPU framework"),
        ]
        let rules = [
            VocabularyReplacementRule(find: "macos", replace: "macOS"),
        ]

        let archive = DictionaryArchive(
            vocabularyTerms: terms,
            substitutionRules: rules,
        )

        let data = try JSONEncoder().encode(archive)
        let decoded = try JSONDecoder().decode(DictionaryArchive.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, DictionaryArchive.currentSchemaVersion)
        XCTAssertEqual(decoded.sourceApp, "Prisma")
        XCTAssertEqual(decoded.vocabularyTerms.count, 2)
        XCTAssertEqual(decoded.substitutionRules.count, 1)
        XCTAssertEqual(decoded.vocabularyTerms[0].term, "SwiftUI")
        XCTAssertEqual(decoded.substitutionRules[0].find, "macos")
    }

    // MARK: - Empty collections

    func testArchiveWithEmptyCollections() throws {
        let archive = DictionaryArchive(
            vocabularyTerms: [],
            substitutionRules: [],
        )

        let data = try JSONEncoder().encode(archive)
        let decoded = try JSONDecoder().decode(DictionaryArchive.self, from: data)

        XCTAssertTrue(decoded.vocabularyTerms.isEmpty)
        XCTAssertTrue(decoded.substitutionRules.isEmpty)
    }

    // MARK: - Validation: valid archive

    func testValidateValidArchive() throws {
        let archive = DictionaryArchive(
            vocabularyTerms: [VocabularyTerm(term: "test", definition: "")],
            substitutionRules: [],
        )

        let data = try JSONEncoder().encode(archive)
        let result = DictionaryArchive.validate(data: data)

        switch result {
        case .success:
            break // expected
        case let .failure(error):
            XCTFail("Expected success, got error: \(error)")
        }
    }

    // MARK: - Validation: unsupported schema version

    func testValidateUnsupportedSchemaVersion() throws {
        let archive = DictionaryArchive(
            schemaVersion: "dictionary_v0",
            vocabularyTerms: [],
            substitutionRules: [],
        )

        let data = try JSONEncoder().encode(archive)
        let result = DictionaryArchive.validate(data: data)

        switch result {
        case .success:
            XCTFail("Expected failure for unsupported schema version")
        case let .failure(error):
            guard case DictionaryArchiveError.unsupportedSchemaVersion = error else {
                XCTFail("Expected unsupportedSchemaVersion error, got: \(error)")
                return
            }
        }
    }

    // MARK: - Validation: corrupt data

    func testValidateCorruptData() {
        let corruptData = Data("not-json-at-all".utf8)
        let result = DictionaryArchive.validate(data: corruptData)

        switch result {
        case .success:
            XCTFail("Expected failure for corrupt data")
        case .failure:
            break // expected
        }
    }

    // MARK: - Merge: no duplicates

    func testMergeWithEmptyExisting() {
        let terms = [VocabularyTerm(term: "Swift", definition: "Language")]
        let rules = [VocabularyReplacementRule(find: "app le", replace: "Apple")]

        let archive = DictionaryArchive(
            vocabularyTerms: terms,
            substitutionRules: rules,
        )

        let result = archive.merge(
            into: [],
            existingRules: [],
        )

        XCTAssertEqual(result.termsImported, 1)
        XCTAssertEqual(result.rulesImported, 1)
        XCTAssertEqual(result.duplicateTermCount, 0)
        XCTAssertEqual(result.duplicateRuleCount, 0)
    }

    // MARK: - Merge: filtered duplicates

    func testMergeSkipsDuplicateTerms() {
        let existingTerms = [VocabularyTerm(term: "Swift", definition: "Existing")]
        let existingRules = [VocabularyReplacementRule(find: "macos", replace: "macOS")]

        let archive = DictionaryArchive(
            vocabularyTerms: [VocabularyTerm(term: "Swift", definition: "Duplicate")],
            substitutionRules: [VocabularyReplacementRule(find: "macos", replace: "macOS")],
        )

        let result = archive.merge(
            into: existingTerms,
            existingRules: existingRules,
        )

        // Term "Swift" already exists (case-insensitive check)
        // "macos" already exists in variants
        XCTAssertEqual(result.termsImported, 0)
        XCTAssertEqual(result.rulesImported, 0)
        XCTAssertEqual(result.duplicateTermCount, 1)
        XCTAssertEqual(result.duplicateRuleCount, 1)
    }

    // MARK: - Merge: partial duplicates

    func testMergeWithPartialDuplicates() {
        let existingTerms = [VocabularyTerm(term: "Swift", definition: "")]
        let existingRules: [VocabularyReplacementRule] = []

        let archive = DictionaryArchive(
            vocabularyTerms: [
                VocabularyTerm(term: "Swift", definition: "Duplicate"),
                VocabularyTerm(term: "Kotlin", definition: "New"),
            ],
            substitutionRules: [
                VocabularyReplacementRule(find: "kotlin", replace: "Kotlin"),
            ],
        )

        let result = archive.merge(
            into: existingTerms,
            existingRules: existingRules,
        )

        XCTAssertEqual(result.termsImported, 1)
        XCTAssertEqual(result.duplicateTermCount, 1)
        XCTAssertEqual(result.rulesImported, 1)
        XCTAssertEqual(result.duplicateRuleCount, 0)
    }

    // MARK: - Merge: all duplicates

    func testMergeAllDuplicates() {
        let existingTerms = [VocabularyTerm(term: "Apple", definition: "")]
        let existingRules = [VocabularyReplacementRule(find: "app le, aple", replace: "Apple")]

        let archive = DictionaryArchive(
            vocabularyTerms: [VocabularyTerm(term: "Apple", definition: "Fruit")],
            substitutionRules: [VocabularyReplacementRule(find: "aple", replace: "Apple")],
        )

        let result = archive.merge(
            into: existingTerms,
            existingRules: existingRules,
        )

        XCTAssertEqual(result.termsImported, 0)
        XCTAssertEqual(result.rulesImported, 0)
        XCTAssertEqual(result.duplicateTermCount, 1)
        XCTAssertEqual(result.duplicateRuleCount, 1)
    }

    // MARK: - Timestamp format

    func testCurrentTimestampISO8601() {
        let timestamp = DictionaryArchive.currentTimestamp()
        let formatter = ISO8601DateFormatter()
        XCTAssertNotNil(formatter.date(from: timestamp), "Timestamp must be valid ISO 8601")
    }
}
