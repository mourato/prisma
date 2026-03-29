import XCTest
@testable import MeetingAssistantCoreInfrastructure

@MainActor
final class NavigationServiceTests: XCTestCase {
    private func resetNavigationService() {
        NavigationService.shared.registerOpenSettingsHandler {}
        NavigationService.shared.registerOpenOnboardingHandler {}
        NavigationService.shared.setSettingsSidebarVisible(true)
    }

    func testOpenSettingsUsesRegisteredHandler() {
        resetNavigationService()
        let expectation = XCTestExpectation(description: "open settings handler invoked")

        NavigationService.shared.registerOpenSettingsHandler {
            expectation.fulfill()
        }

        NavigationService.shared.openSettings()
        wait(for: [expectation], timeout: 1)
    }

    func testOpenOnboardingUsesRegisteredHandler() {
        resetNavigationService()
        let expectation = XCTestExpectation(description: "open onboarding handler invoked")

        NavigationService.shared.registerOpenOnboardingHandler {
            expectation.fulfill()
        }

        NavigationService.shared.openOnboarding()
        wait(for: [expectation], timeout: 1)
    }

    func testRequestSettingsSidebarToggleIncrementsRequestID() {
        resetNavigationService()
        let initialValue = NavigationService.shared.settingsSidebarToggleRequestID

        NavigationService.shared.requestSettingsSidebarToggle()

        XCTAssertEqual(NavigationService.shared.settingsSidebarToggleRequestID, initialValue + 1)
    }

    func testSetSettingsSidebarVisiblePublishesCurrentState() {
        resetNavigationService()
        NavigationService.shared.setSettingsSidebarVisible(false)

        XCTAssertFalse(NavigationService.shared.isSettingsSidebarVisible)
    }
}
