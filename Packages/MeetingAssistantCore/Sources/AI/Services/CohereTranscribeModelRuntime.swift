@preconcurrency import CoreML
@preconcurrency import FluidAudio
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import os.log

enum CohereTranscribeModelRuntime {
    private static let logger = Logger(
        subsystem: AppIdentity.logSubsystem,
        category: "CohereTranscribeModelRuntime"
    )

    private static let remoteRepoPath = "FluidInference/cohere-transcribe-03-2026-coreml-6bit"

    private static let requiredModelDirectoryNames = [
        ModelNames.ASR.preprocessorFile,
        ModelNames.ASR.encoderFile,
        ModelNames.ASR.decoderFile,
        ModelNames.ASR.jointFile,
    ]

    private static let vocabularyCandidates = [
        ModelNames.ASR.vocabularyFile,
        "vocab.json",
        "cohere_vocab.json",
    ]

    enum RuntimeError: LocalizedError {
        case missingRequiredArtifacts([String])
        case vocabularyNotFound
        case vocabularyUnreadable(String)

        var errorDescription: String? {
            switch self {
            case let .missingRequiredArtifacts(missing):
                "Missing required Cohere model artifacts: \(missing.joined(separator: ", "))."
            case .vocabularyNotFound:
                "Could not find a vocabulary file for the Cohere local model."
            case let .vocabularyUnreadable(reason):
                "Unable to parse Cohere vocabulary: \(reason)"
            }
        }
    }

    static func defaultCacheDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        return appSupport
            .appendingPathComponent("FluidAudio", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(
                LocalTranscriptionModel.cohereTranscribe032026CoreML6Bit.rawValue,
                isDirectory: true
            )
    }

    static func modelsExist(at directory: URL = defaultCacheDirectory()) -> Bool {
        requiredModelDirectoryNames.allSatisfy { modelDirectoryName in
            (try? findDirectory(named: modelDirectoryName, under: directory)) != nil
        } && (try? findVocabularyFile(under: directory)) != nil
    }

    static func downloadIfNeeded(force: Bool = false) async throws -> URL {
        let targetDirectory = defaultCacheDirectory()
        let fileManager = FileManager.default

        if !force, modelsExist(at: targetDirectory) {
            logger.info("Cohere local model already available at \(targetDirectory.path, privacy: .public)")
            return targetDirectory
        }

        if force, fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.removeItem(at: targetDirectory)
        }

        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        logger.info("Downloading Cohere local model artifacts from Hugging Face...")
        let files = try await HuggingFaceRepositoryDownloader.listFilesRecursively(repoPath: remoteRepoPath)
        let filteredFiles = files.filter { shouldDownload(path: $0.path) }

        if filteredFiles.isEmpty {
            throw RuntimeError.missingRequiredArtifacts(requiredModelDirectoryNames + vocabularyCandidates)
        }

        try await HuggingFaceRepositoryDownloader.downloadFiles(
            repoPath: remoteRepoPath,
            files: filteredFiles,
            to: targetDirectory
        )

        let missing = requiredModelDirectoryNames.filter { name in
            (try? findDirectory(named: name, under: targetDirectory)) == nil
        }

        if !missing.isEmpty {
            throw RuntimeError.missingRequiredArtifacts(missing)
        }

        if (try? findVocabularyFile(under: targetDirectory)) == nil {
            throw RuntimeError.vocabularyNotFound
        }

        logger.info("Finished Cohere local model download.")
        return targetDirectory
    }

    static func downloadAndLoad(configuration: MLModelConfiguration? = nil) async throws -> AsrModels {
        let targetDirectory = try await downloadIfNeeded()
        return try load(from: targetDirectory, configuration: configuration)
    }

    static func load(from directory: URL, configuration: MLModelConfiguration? = nil) throws -> AsrModels {
        let config = configuration ?? AsrModels.defaultConfiguration()

        let preprocessorURL = try findDirectory(named: ModelNames.ASR.preprocessorFile, under: directory)
        let encoderURL = try findDirectory(named: ModelNames.ASR.encoderFile, under: directory)
        let decoderURL = try findDirectory(named: ModelNames.ASR.decoderFile, under: directory)
        let jointURL = try findDirectory(named: ModelNames.ASR.jointFile, under: directory)
        let vocabularyURL = try findVocabularyFile(under: directory)

        let preprocessorConfig = MLModelConfiguration()
        preprocessorConfig.allowLowPrecisionAccumulationOnGPU = true
        preprocessorConfig.computeUnits = .cpuOnly

        let encoderModel = try MLModel(contentsOf: encoderURL, configuration: config)
        let preprocessorModel = try MLModel(contentsOf: preprocessorURL, configuration: preprocessorConfig)
        let decoderModel = try MLModel(contentsOf: decoderURL, configuration: config)
        let jointModel = try MLModel(contentsOf: jointURL, configuration: config)

        let vocabulary = try loadVocabulary(from: vocabularyURL)

        return AsrModels(
            encoder: encoderModel,
            preprocessor: preprocessorModel,
            decoder: decoderModel,
            joint: jointModel,
            configuration: config,
            vocabulary: vocabulary,
            version: .v3
        )
    }

    private static func shouldDownload(path: String) -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        if vocabularyCandidates.contains(fileName) {
            return true
        }

        return requiredModelDirectoryNames.contains { directoryName in
            path.contains("/\(directoryName)/") || path.hasPrefix("\(directoryName)/")
        }
    }

    private static func findDirectory(named targetName: String, under rootDirectory: URL) throws -> URL {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard
            let enumerator = FileManager.default.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        else {
            throw RuntimeError.missingRequiredArtifacts([targetName])
        }

        for case let candidateURL as URL in enumerator {
            guard candidateURL.lastPathComponent == targetName else { continue }
            let values = try candidateURL.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true {
                return candidateURL
            }
        }

        throw RuntimeError.missingRequiredArtifacts([targetName])
    }

    private static func findVocabularyFile(under rootDirectory: URL) throws -> URL {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard
            let enumerator = FileManager.default.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        else {
            throw RuntimeError.vocabularyNotFound
        }

        for case let candidateURL as URL in enumerator {
            let fileName = candidateURL.lastPathComponent
            guard vocabularyCandidates.contains(fileName) else { continue }
            let values = try candidateURL.resourceValues(forKeys: Set(keys))
            if values.isDirectory != true {
                return candidateURL
            }
        }

        throw RuntimeError.vocabularyNotFound
    }

    private static func loadVocabulary(from vocabularyURL: URL) throws -> [Int: String] {
        let data = try Data(contentsOf: vocabularyURL)
        let json = try JSONSerialization.jsonObject(with: data)

        if let dictionary = json as? [String: String] {
            var vocabulary: [Int: String] = [:]
            for (key, value) in dictionary {
                if let tokenID = Int(key) {
                    vocabulary[tokenID] = value
                }
            }
            if !vocabulary.isEmpty {
                return vocabulary
            }
        }

        if let array = json as? [String], !array.isEmpty {
            var vocabulary: [Int: String] = [:]
            for (index, token) in array.enumerated() {
                vocabulary[index] = token
            }
            return vocabulary
        }

        throw RuntimeError.vocabularyUnreadable(vocabularyURL.lastPathComponent)
    }
}
