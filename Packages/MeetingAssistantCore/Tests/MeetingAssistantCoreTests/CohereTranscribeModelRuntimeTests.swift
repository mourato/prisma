import Foundation
import XCTest
@testable import MeetingAssistantCoreAI
@testable import MeetingAssistantCoreInfrastructure

final class CohereTranscribeModelRuntimeTests: XCTestCase {
    func testParseVocabularyData_WhenCoreMLManifestContainsIDToToken_ReturnsIndexedVocabulary() throws {
        let payload: [String: Any] = [
            "model_id": "CohereLabs/cohere-transcribe-03-2026",
            "id_to_token": ["<unk>", "hello", "world"],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        let vocabulary = try CohereTranscribeModelRuntime.parseVocabularyData(
            data,
            sourceName: "coreml_manifest.json"
        )

        XCTAssertEqual(vocabulary[0], "<unk>")
        XCTAssertEqual(vocabulary[1], "hello")
        XCTAssertEqual(vocabulary[2], "world")
        XCTAssertEqual(vocabulary.count, 3)
    }

    func testParseVocabularyData_WhenNumericDictionaryFormat_ReturnsMappedVocabulary() throws {
        let payload = [
            "0": "<unk>",
            "1": "ola",
        ]
        let data = try JSONEncoder().encode(payload)

        let vocabulary = try CohereTranscribeModelRuntime.parseVocabularyData(
            data,
            sourceName: "vocab.json"
        )

        XCTAssertEqual(vocabulary[0], "<unk>")
        XCTAssertEqual(vocabulary[1], "ola")
        XCTAssertEqual(vocabulary.count, 2)
    }

    func testModelsExist_WhenPublicCohereArtifactsAndManifestExist_ReturnsTrue() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        for folder in [
            "cohere_frontend.mlpackage",
            "cohere_encoder.mlpackage",
            "cohere_decoder_cached.mlpackage",
            "cohere_cross_kv_projector.mlpackage",
        ] {
            let folderURL = directory.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        let manifestURL = directory.appendingPathComponent("coreml_manifest.json")
        let manifestPayload: [String: Any] = ["id_to_token": ["<unk>", "hi"]]
        let manifestData = try JSONSerialization.data(withJSONObject: manifestPayload)
        try manifestData.write(to: manifestURL)

        XCTAssertTrue(CohereTranscribeModelRuntime.modelsExist(at: directory))
    }

    func testModelsExist_WhenJointArtifactIsMissing_ReturnsFalse() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        for folder in [
            "cohere_frontend.mlpackage",
            "cohere_encoder.mlpackage",
            "cohere_decoder_cached.mlpackage",
        ] {
            let folderURL = directory.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        let manifestURL = directory.appendingPathComponent("coreml_manifest.json")
        let manifestPayload: [String: Any] = ["id_to_token": ["<unk>", "hi"]]
        let manifestData = try JSONSerialization.data(withJSONObject: manifestPayload)
        try manifestData.write(to: manifestURL)

        XCTAssertFalse(CohereTranscribeModelRuntime.modelsExist(at: directory))
    }

    @MainActor
    func testCohereLoadIntegration_WhenEnabled_LoadsModelManagerSuccessfully() async throws {
        guard ProcessInfo.processInfo.environment["PRISMA_ENABLE_COHERE_RUNTIME_INTEGRATION_TEST"] == "1" else {
            throw XCTSkip("Set PRISMA_ENABLE_COHERE_RUNTIME_INTEGRATION_TEST=1 to enable this runtime integration test.")
        }

        let manager = FluidAIModelManager.shared
        await manager.loadModels(for: LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue)

        XCTAssertEqual(
            manager.modelState,
            .loaded,
            "Expected Cohere model to load successfully. Current state: \(manager.modelState.rawValue), lastError: \(manager.lastError ?? "nil")"
        )
        XCTAssertEqual(
            manager.loadedASRLocalModelID,
            LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue,
            "Loaded model ID did not match Cohere selection."
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CohereRuntimeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
