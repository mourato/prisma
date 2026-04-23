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

    /// Try the public FluidVoice-compatible source first, then fallback to the
    /// private FluidInference mirror for environments that have credentials.
    private static let remoteRepoCandidates = [
        "BarathwajAnandan/cohere-transcribe-03-2026-CoreML-6bit",
        "FluidInference/cohere-transcribe-03-2026-coreml-6bit",
    ]

    private enum ModelComponent: String, CaseIterable {
        case preprocessor
        case encoder
        case decoder
        case joint

        var displayName: String {
            switch self {
            case .preprocessor:
                "Preprocessor"
            case .encoder:
                "Encoder"
            case .decoder:
                "Decoder"
            case .joint:
                "Joint"
            }
        }

        var artifactCandidates: [String] {
            switch self {
            case .preprocessor:
                [
                    ModelNames.ASR.preprocessorFile,
                    "cohere_frontend.mlmodelc",
                    "cohere_frontend.mlpackage",
                ]
            case .encoder:
                [
                    ModelNames.ASR.encoderFile,
                    "cohere_encoder.mlmodelc",
                    "cohere_encoder.mlpackage",
                ]
            case .decoder:
                [
                    ModelNames.ASR.decoderFile,
                    "cohere_decoder_cached.mlmodelc",
                    "cohere_decoder_cached.mlpackage",
                    "cohere_decoder_stateful.mlmodelc",
                    "cohere_decoder_stateful.mlpackage",
                ]
            case .joint:
                [
                    ModelNames.ASR.jointFile,
                    "cohere_cross_kv_projector.mlmodelc",
                    "cohere_cross_kv_projector.mlpackage",
                    "cohere_decoder_fullseq_masked.mlmodelc",
                    "cohere_decoder_fullseq_masked.mlpackage",
                ]
            }
        }
    }

    private static let requiredModelArtifactCandidates = ModelComponent.allCases.flatMap(\.artifactCandidates)

    private static let vocabularyCandidates = [
        ModelNames.ASR.vocabularyFile,
        "vocab.json",
        "cohere_vocab.json",
        "coreml_manifest.json",
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
        missingComponents(under: directory).isEmpty
            && (try? findVocabularyFile(under: directory)) != nil
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

        var lastError: Error?

        for repoPath in remoteRepoCandidates {
            do {
                if fileManager.fileExists(atPath: targetDirectory.path) {
                    try fileManager.removeItem(at: targetDirectory)
                }
                try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

                logger.info("Downloading Cohere local model artifacts from Hugging Face repo: \(repoPath, privacy: .public)")
                let files = try await HuggingFaceRepositoryDownloader.listFilesRecursively(repoPath: repoPath)
                let filteredFiles = files.filter { shouldDownload(path: $0.path) }

                if filteredFiles.isEmpty {
                    throw RuntimeError.missingRequiredArtifacts(requiredModelArtifactCandidates + vocabularyCandidates)
                }

                try await HuggingFaceRepositoryDownloader.downloadFiles(
                    repoPath: repoPath,
                    files: filteredFiles,
                    to: targetDirectory
                )

                let missing = missingComponents(under: targetDirectory)
                if !missing.isEmpty {
                    throw RuntimeError.missingRequiredArtifacts(missing)
                }

                if (try? findVocabularyFile(under: targetDirectory)) == nil {
                    throw RuntimeError.vocabularyNotFound
                }

                logger.info("Finished Cohere local model download from repo: \(repoPath, privacy: .public)")
                return targetDirectory
            } catch {
                lastError = error
                logger.error("Cohere download attempt failed for repo \(repoPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if fileManager.fileExists(atPath: targetDirectory.path) {
            try? fileManager.removeItem(at: targetDirectory)
        }

        throw lastError ?? RuntimeError.missingRequiredArtifacts(requiredModelArtifactCandidates + vocabularyCandidates)
    }

    static func downloadAndLoad(configuration: MLModelConfiguration? = nil) async throws -> AsrModels {
        let targetDirectory = try await downloadIfNeeded()
        return try load(from: targetDirectory, configuration: configuration)
    }

    static func load(from directory: URL, configuration: MLModelConfiguration? = nil) throws -> AsrModels {
        var config = configuration ?? AsrModels.defaultConfiguration()
        if configuration == nil {
            // Cohere public CoreML packages are frequently distributed as
            // portable .mlpackage exports; forcing ANE at first load can
            // trigger long plan-build stalls. Default to CPU+GPU for stability.
            config.computeUnits = .cpuAndGPU
        }

        let preprocessorURL = try findDirectory(
            matchingAnyOf: ModelComponent.preprocessor.artifactCandidates,
            under: directory
        )
        let encoderURL = try findDirectory(
            matchingAnyOf: ModelComponent.encoder.artifactCandidates,
            under: directory
        )
        let decoderURL = try findDirectory(
            matchingAnyOf: ModelComponent.decoder.artifactCandidates,
            under: directory
        )
        let jointURL = try findDirectory(
            matchingAnyOf: ModelComponent.joint.artifactCandidates,
            under: directory
        )
        let vocabularyURL = try findVocabularyFile(under: directory)

        let preprocessorConfig = MLModelConfiguration()
        preprocessorConfig.allowLowPrecisionAccumulationOnGPU = true
        preprocessorConfig.computeUnits = .cpuOnly

        let encoderModel = try loadModel(from: encoderURL, configuration: config)
        let preprocessorModel = try loadModel(from: preprocessorURL, configuration: preprocessorConfig)
        let decoderModel = try loadModel(from: decoderURL, configuration: config)
        let jointModel = try loadModel(from: jointURL, configuration: config)

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

    private static func loadModel(from artifactURL: URL, configuration: MLModelConfiguration) throws -> MLModel {
        // Public Cohere repos commonly ship .mlpackage artifacts. Compile them
        // on-device before loading to avoid "not a valid .mlmodelc" runtime failures.
        if artifactURL.pathExtension == "mlpackage" {
            let compiledURL = try MLModel.compileModel(at: artifactURL)
            return try MLModel(contentsOf: compiledURL, configuration: configuration)
        }

        return try MLModel(contentsOf: artifactURL, configuration: configuration)
    }

    private static func shouldDownload(path: String) -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        if vocabularyCandidates.contains(fileName) {
            return true
        }

        return requiredModelArtifactCandidates.contains { directoryName in
            path.contains("/\(directoryName)/") || path.hasPrefix("\(directoryName)/")
        }
    }

    private static func missingComponents(under rootDirectory: URL) -> [String] {
        ModelComponent.allCases.compactMap { component in
            let exists = (try? findDirectory(matchingAnyOf: component.artifactCandidates, under: rootDirectory)) != nil
            return exists ? nil : component.displayName
        }
    }

    private static func findDirectory(matchingAnyOf targetNames: [String], under rootDirectory: URL) throws -> URL {
        for targetName in targetNames {
            if let found = try? findDirectory(named: targetName, under: rootDirectory) {
                return found
            }
        }

        throw RuntimeError.missingRequiredArtifacts(targetNames)
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
        return try parseVocabularyData(data, sourceName: vocabularyURL.lastPathComponent)
    }

    static func parseVocabularyData(_ data: Data, sourceName: String) throws -> [Int: String] {
        let json = try JSONSerialization.jsonObject(with: data)

        if
            let dictionary = json as? [String: Any],
            let tokens = dictionary["id_to_token"] as? [String],
            !tokens.isEmpty
        {
            var vocabulary: [Int: String] = [:]
            for (index, token) in tokens.enumerated() {
                vocabulary[index] = token
            }
            return vocabulary
        }

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

        throw RuntimeError.vocabularyUnreadable(sourceName)
    }
}
