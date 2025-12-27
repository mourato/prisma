import Combine
import Foundation
import SwiftUI

@MainActor
public class TranscriptionViewModel: ObservableObject {
    // MARK: - Dependencies

    private let status: TranscriptionStatus
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties for UI (Computed Proxies)

    public var statusMessage: String { self.status.statusMessage }
    public var progressPercentage: Double { self.status.progressPercentage }
    public var estimatedTimeRemaining: TimeInterval? { self.status.estimatedTimeRemaining }
    public var isProcessing: Bool { self.status.isProcessing }
    public var hasBlockingError: Bool { self.status.hasBlockingError }
    public var phase: TranscriptionPhase { self.status.phase }
    public var serviceState: ServiceState { self.status.serviceState }
    public var modelState: ModelState { self.status.modelState }
    public var lastError: TranscriptionStatusError? { self.status.lastError }
    public var device: String { self.status.device }

    // MARK: - Computed Properties

    public var isReady: Bool {
        self.serviceState == .connected && self.modelState == .loaded && self.phase == .idle
    }

    // MARK: - Initialization

    public init(status: TranscriptionStatus) {
        self.status = status
        self.setupBindings()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Forward all changes from the model to the view model
        self.status.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &self.cancellables)
    }
}
