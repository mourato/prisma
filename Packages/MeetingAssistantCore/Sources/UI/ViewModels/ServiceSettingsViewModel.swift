import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

@MainActor
public class ServiceSettingsViewModel: ObservableObject {
    @Published public var transcriptionStatus: ConnectionStatus = .unknown
    @Published public var modelState: FluidAIModelManager.ModelState = .unloaded
    @Published public var isASRInstalled: Bool = false
    @Published public var isDiarizationLoaded: Bool = false

    private let transcriptionClient: TranscriptionClient
    private var cancellables = Set<AnyCancellable>()

    public init(transcriptionClient: TranscriptionClient = .shared) {
        self.transcriptionClient = transcriptionClient

        modelState = FluidAIModelManager.shared.modelState
        isASRInstalled = FluidAIModelManager.shared.isASRInstalled
        isDiarizationLoaded = FluidAIModelManager.shared.isDiarizationLoaded

        FluidAIModelManager.shared.$modelState
            .receive(on: DispatchQueue.main)
            .assign(to: \.modelState, on: self)
            .store(in: &cancellables)

        FluidAIModelManager.shared.$isASRInstalled
            .receive(on: DispatchQueue.main)
            .assign(to: \.isASRInstalled, on: self)
            .store(in: &cancellables)

        FluidAIModelManager.shared.$isDiarizationLoaded
            .receive(on: DispatchQueue.main)
            .assign(to: \.isDiarizationLoaded, on: self)
            .store(in: &cancellables)

        refreshInstalledModelStates()
    }

    public func testConnection() {
        transcriptionStatus = .testing

        Task {
            do {
                let isHealthy = try await self.transcriptionClient.healthCheck()
                self.transcriptionStatus = isHealthy ? .success : .failure(nil)
            } catch {
                self.transcriptionStatus = .failure(error.localizedDescription)
            }
        }
    }

    public func deleteASRModels() {
        Task {
            FluidAIModelManager.shared.deleteASRModels()
        }
    }

    public func downloadASRModels() {
        Task {
            await FluidAIModelManager.shared.loadModels()
        }
    }

    public func downloadDiarizationModels() {
        Task {
            await FluidAIModelManager.shared.loadDiarizationModels()
        }
    }

    public func deleteDiarizationModels() {
        Task {
            FluidAIModelManager.shared.deleteDiarizationModels()
        }
    }

    public func refreshInstalledModelStates() {
        FluidAIModelManager.shared.refreshInstalledModelStates()
    }
}
