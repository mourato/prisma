import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import os.log

@MainActor
protocol LocalModelResidencyManaging: AnyObject {
    var lastASRActivityAt: Date? { get }
    var lastDiarizationActivityAt: Date? { get }
    var isASRInUse: Bool { get }
    var isDiarizationInUse: Bool { get }
    var isASRResidentInMemory: Bool { get }
    var isDiarizationResidentInMemory: Bool { get }
    @discardableResult func unloadASRFromMemoryIfPossible() -> Bool
    @discardableResult func unloadDiarizationFromMemoryIfPossible() -> Bool
}

extension FluidAIModelManager: LocalModelResidencyManaging {}

@MainActor
protocol ModelResidencyTimeoutSettingsProviding: AnyObject {
    var modelResidencyTimeout: AppSettingsStore.ModelResidencyTimeoutOption { get }
}

extension AppSettingsStore: ModelResidencyTimeoutSettingsProviding {}

@MainActor
public final class LocalModelResidencyCoordinator {
    public static let shared = LocalModelResidencyCoordinator()

    private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "LocalModelResidencyCoordinator")
    private let modelManager: any LocalModelResidencyManaging
    private let settingsStore: any ModelResidencyTimeoutSettingsProviding
    private let checkIntervalNanoseconds: UInt64

    private var monitorTask: Task<Void, Never>?

    init(
        modelManager: any LocalModelResidencyManaging = FluidAIModelManager.shared,
        settingsStore: any ModelResidencyTimeoutSettingsProviding = AppSettingsStore.shared,
        checkIntervalSeconds: TimeInterval = 30
    ) {
        self.modelManager = modelManager
        self.settingsStore = settingsStore
        let clampedInterval = max(1, checkIntervalSeconds)
        checkIntervalNanoseconds = UInt64(clampedInterval * 1_000_000_000)
    }

    deinit {
        monitorTask?.cancel()
    }

    public func startMonitoring() {
        guard monitorTask == nil else { return }

        logger.info("Starting local model residency monitoring.")
        monitorTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                evaluateAndUnloadIfNeeded(now: Date())
                try? await Task.sleep(nanoseconds: checkIntervalNanoseconds)
            }
        }
    }

    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func evaluateAndUnloadIfNeeded(now: Date = Date()) {
        guard let timeoutInterval = settingsStore.modelResidencyTimeout.inactivityInterval else {
            return
        }

        if shouldUnloadASR(now: now, timeoutInterval: timeoutInterval),
           modelManager.unloadASRFromMemoryIfPossible()
        {
            logger.info("Auto-unloaded ASR model from RAM after inactivity threshold.")
        }

        if shouldUnloadDiarization(now: now, timeoutInterval: timeoutInterval),
           modelManager.unloadDiarizationFromMemoryIfPossible()
        {
            logger.info("Auto-unloaded diarization model from RAM after inactivity threshold.")
        }
    }

    private func shouldUnloadASR(now: Date, timeoutInterval: TimeInterval) -> Bool {
        guard modelManager.isASRResidentInMemory else { return false }
        guard !modelManager.isASRInUse else { return false }
        guard let lastActivity = modelManager.lastASRActivityAt else { return false }
        return now.timeIntervalSince(lastActivity) >= timeoutInterval
    }

    private func shouldUnloadDiarization(now: Date, timeoutInterval: TimeInterval) -> Bool {
        guard modelManager.isDiarizationResidentInMemory else { return false }
        guard !modelManager.isDiarizationInUse else { return false }
        guard let lastActivity = modelManager.lastDiarizationActivityAt else { return false }
        return now.timeIntervalSince(lastActivity) >= timeoutInterval
    }
}
