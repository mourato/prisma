import Foundation
import XCTest
@testable import MeetingAssistantCoreAI
@testable import MeetingAssistantCoreInfrastructure

@MainActor
final class LocalModelResidencyCoordinatorTests: XCTestCase {
    func testEvaluateDoesNotUnloadWhenTimeoutIsNever() {
        let manager = MockLocalModelResidencyManager(
            asrResident: true,
            diarizationResident: true,
            lastASRActivityAt: Date(timeIntervalSince1970: 0),
            lastDiarizationActivityAt: Date(timeIntervalSince1970: 0)
        )
        let settings = MockModelResidencySettings(timeout: .never)
        let coordinator = LocalModelResidencyCoordinator(
            modelManager: manager,
            settingsStore: settings,
            checkIntervalSeconds: 1
        )

        coordinator.evaluateAndUnloadIfNeeded(now: Date(timeIntervalSince1970: 10_000))

        XCTAssertEqual(manager.asrUnloadAttempts, 0)
        XCTAssertEqual(manager.diarizationUnloadAttempts, 0)
    }

    func testEvaluateUnloadsBothModelsWhenInactivityThresholdIsExceeded() {
        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let manager = MockLocalModelResidencyManager(
            asrResident: true,
            diarizationResident: true,
            lastASRActivityAt: referenceDate,
            lastDiarizationActivityAt: referenceDate
        )
        let settings = MockModelResidencySettings(timeout: .minutes5)
        let coordinator = LocalModelResidencyCoordinator(
            modelManager: manager,
            settingsStore: settings,
            checkIntervalSeconds: 1
        )

        coordinator.evaluateAndUnloadIfNeeded(now: referenceDate.addingTimeInterval(5 * 60))

        XCTAssertEqual(manager.asrUnloadAttempts, 1)
        XCTAssertEqual(manager.diarizationUnloadAttempts, 1)
        XCTAssertFalse(manager.isASRResidentInMemory)
        XCTAssertFalse(manager.isDiarizationResidentInMemory)
    }

    func testEvaluateSkipsUnloadWhenModelsAreInUse() {
        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let manager = MockLocalModelResidencyManager(
            asrResident: true,
            diarizationResident: true,
            lastASRActivityAt: referenceDate,
            lastDiarizationActivityAt: referenceDate,
            isASRInUse: true,
            isDiarizationInUse: true
        )
        let settings = MockModelResidencySettings(timeout: .minutes5)
        let coordinator = LocalModelResidencyCoordinator(
            modelManager: manager,
            settingsStore: settings,
            checkIntervalSeconds: 1
        )

        coordinator.evaluateAndUnloadIfNeeded(now: referenceDate.addingTimeInterval(15 * 60))

        XCTAssertEqual(manager.asrUnloadAttempts, 0)
        XCTAssertEqual(manager.diarizationUnloadAttempts, 0)
    }

    func testEvaluateSkipsUnloadBeforeThreshold() {
        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let manager = MockLocalModelResidencyManager(
            asrResident: true,
            diarizationResident: true,
            lastASRActivityAt: referenceDate,
            lastDiarizationActivityAt: referenceDate
        )
        let settings = MockModelResidencySettings(timeout: .minutes10)
        let coordinator = LocalModelResidencyCoordinator(
            modelManager: manager,
            settingsStore: settings,
            checkIntervalSeconds: 1
        )

        coordinator.evaluateAndUnloadIfNeeded(now: referenceDate.addingTimeInterval(9 * 60))

        XCTAssertEqual(manager.asrUnloadAttempts, 0)
        XCTAssertEqual(manager.diarizationUnloadAttempts, 0)
    }
}

@MainActor
private final class MockModelResidencySettings: ModelResidencyTimeoutSettingsProviding {
    var modelResidencyTimeout: AppSettingsStore.ModelResidencyTimeoutOption

    init(timeout: AppSettingsStore.ModelResidencyTimeoutOption) {
        modelResidencyTimeout = timeout
    }
}

@MainActor
private final class MockLocalModelResidencyManager: LocalModelResidencyManaging {
    var lastASRActivityAt: Date?
    var lastDiarizationActivityAt: Date?
    var isASRInUse: Bool
    var isDiarizationInUse: Bool
    var isASRResidentInMemory: Bool
    var isDiarizationResidentInMemory: Bool

    private(set) var asrUnloadAttempts = 0
    private(set) var diarizationUnloadAttempts = 0

    init(
        asrResident: Bool,
        diarizationResident: Bool,
        lastASRActivityAt: Date?,
        lastDiarizationActivityAt: Date?,
        isASRInUse: Bool = false,
        isDiarizationInUse: Bool = false
    ) {
        isASRResidentInMemory = asrResident
        isDiarizationResidentInMemory = diarizationResident
        self.lastASRActivityAt = lastASRActivityAt
        self.lastDiarizationActivityAt = lastDiarizationActivityAt
        self.isASRInUse = isASRInUse
        self.isDiarizationInUse = isDiarizationInUse
    }

    @discardableResult
    func unloadASRFromMemoryIfPossible() -> Bool {
        asrUnloadAttempts += 1
        guard isASRResidentInMemory else { return false }
        isASRResidentInMemory = false
        return true
    }

    @discardableResult
    func unloadDiarizationFromMemoryIfPossible() -> Bool {
        diarizationUnloadAttempts += 1
        guard isDiarizationResidentInMemory else { return false }
        isDiarizationResidentInMemory = false
        return true
    }
}
