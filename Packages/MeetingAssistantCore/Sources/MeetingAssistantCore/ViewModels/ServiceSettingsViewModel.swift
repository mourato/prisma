import Combine
import Foundation
import SwiftUI

@MainActor
public class ServiceSettingsViewModel: ObservableObject {
    @Published public var transcriptionStatus: ConnectionStatus = .unknown
    @Published public var modelState: FluidAIModelManager.ModelState = .unloaded
    @Published public var isDiarizationLoaded: Bool = false

    private let transcriptionClient: TranscriptionClient
    private var cancellables = Set<AnyCancellable>()

    public init(transcriptionClient: TranscriptionClient = .shared) {
        self.transcriptionClient = transcriptionClient

        FluidAIModelManager.shared.$modelState
            .receive(on: DispatchQueue.main)
            .assign(to: \.modelState, on: self)
            .store(in: &cancellables)

        FluidAIModelManager.shared.$isDiarizationLoaded
            .receive(on: DispatchQueue.main)
            .assign(to: \.isDiarizationLoaded, on: self)
            .store(in: &cancellables)
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

    public func deleteDiarizationModels() {
        Task {
            FluidAIModelManager.shared.deleteDiarizationModels()
        }
    }
}
