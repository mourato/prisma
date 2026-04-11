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
    private let settings: AppSettingsStore
    private let keychain: KeychainProvider
    private var cancellables = Set<AnyCancellable>()

    public init(
        transcriptionClient: TranscriptionClient = .shared,
        settings: AppSettingsStore = .shared,
        keychain: KeychainProvider = DefaultKeychainProvider()
    ) {
        self.transcriptionClient = transcriptionClient
        self.settings = settings
        self.keychain = keychain

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

        settings.$modelResidencyTimeout
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
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

    public var selectedDictationProvider: MeetingAssistantCoreInfrastructure.TranscriptionProvider {
        settings.transcriptionDictationSelection.provider
    }

    public var selectedDictationProviderRawValue: String {
        selectedDictationProvider.rawValue
    }

    public var selectedDictationModel: String {
        settings.transcriptionDictationSelection.selectedModel
    }

    public var availableDictationProviders: [MeetingAssistantCoreInfrastructure.TranscriptionProvider] {
        MeetingAssistantCoreInfrastructure.TranscriptionProvider.allCases
    }

    public var availableDictationModels: [String] {
        switch selectedDictationProvider {
        case .local:
            [MeetingAssistantCoreInfrastructure.TranscriptionProvider.localModelID]
        case .groq:
            MeetingAssistantCoreInfrastructure.TranscriptionProvider.groqPresetModelIDs
        }
    }

    public var modelResidencyTimeoutOptions: [AppSettingsStore.ModelResidencyTimeoutOption] {
        AppSettingsStore.ModelResidencyTimeoutOption.allCases
    }

    public var modelResidencyTimeout: AppSettingsStore.ModelResidencyTimeoutOption {
        get {
            settings.modelResidencyTimeout
        }
        set {
            settings.modelResidencyTimeout = newValue
        }
    }

    public var shouldShowGroqAPIKeyActions: Bool {
        selectedDictationProvider == .groq
    }

    public var isDictationProviderReady: Bool {
        switch selectedDictationProvider {
        case .local:
            true
        case .groq:
            keychain.existsAPIKey(for: .groq)
        }
    }

    public func updateDictationProvider(rawValue: String) {
        guard let provider = MeetingAssistantCoreInfrastructure.TranscriptionProvider(rawValue: rawValue) else {
            return
        }
        settings.updateTranscriptionDictationProvider(provider)
        objectWillChange.send()
    }

    public func updateDictationModel(_ model: String) {
        settings.updateTranscriptionDictationModel(model)
        objectWillChange.send()
    }
}
