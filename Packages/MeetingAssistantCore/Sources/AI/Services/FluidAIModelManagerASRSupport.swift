@preconcurrency import FluidAudio
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import os.log

extension FluidAIModelManager {
    func hasASRModelsOnDisk() -> Bool {
        LocalTranscriptionModel.allCases.contains { model in
            isASRModelInstalled(localModelID: model.rawValue)
        }
    }

    public func isASRModelInstalled(localModelID: String) -> Bool {
        guard let model = LocalTranscriptionModel(rawValue: localModelID) else { return false }

        switch model {
        case .parakeetTdt06BV3:
            return AsrModels.modelsExist(
                at: AsrModels.defaultCacheDirectory(for: .v3),
                version: .v3
            )
        case .cohereTranscribe032026CoreML6Bit:
            return CohereTranscribeModelRuntime.modelsExist()
        }
    }

    func resolveLocalModel(from rawValue: String) -> LocalTranscriptionModel {
        LocalTranscriptionModel(rawValue: rawValue) ?? .parakeetTdt06BV3
    }

    func loadASRModels(for model: LocalTranscriptionModel) async throws -> AsrModels {
        switch model {
        case .parakeetTdt06BV3:
            try await AsrModels.downloadAndLoad(version: .v3)
        case .cohereTranscribe032026CoreML6Bit:
            try await CohereTranscribeModelRuntime.downloadAndLoad()
        }
    }

    func hasDiarizationModelsOnDisk() -> Bool {
        let fallbackLogger = Logger(subsystem: AppIdentity.logSubsystem, category: "FluidAIModelManager")
        let fileManager = FileManager.default
        guard let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }

        let modelsDir = supportDir.appendingPathComponent("FluidAudio/Models")
        guard fileManager.fileExists(atPath: modelsDir.path) else {
            return false
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: nil)
            return contents.contains { url in
                let name = url.lastPathComponent.lowercased()
                return name.contains("pyannote") || name.contains("segmentation")
            }
        } catch {
            fallbackLogger.error("Failed to inspect Diarization model directory: \(error.localizedDescription)")
            return false
        }
    }
}
