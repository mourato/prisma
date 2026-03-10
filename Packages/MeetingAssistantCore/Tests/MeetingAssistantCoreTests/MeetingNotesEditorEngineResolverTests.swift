import Foundation
@testable import MeetingAssistantCoreUI
import XCTest

final class MeetingNotesEditorEngineResolverTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MeetingNotesEditorEngineResolverTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testResolveWithoutOverridesDefaultsToTextual() {
        let resolver = makeResolver(environment: [:])

        XCTAssertEqual(resolver.resolve(), .textual)
    }

    func testResolveUsesEnvironmentWhenValid() {
        let resolver = makeResolver(environment: [MeetingNotesEditorEngineResolver.environmentKey: "native"])

        XCTAssertEqual(resolver.resolve(), .native)
    }

    func testResolveFallsBackToTextualWhenEnvironmentIsInvalid() {
        let resolver = makeResolver(environment: [MeetingNotesEditorEngineResolver.environmentKey: "unsupported"])

        XCTAssertEqual(resolver.resolve(), .textual)
    }

    func testResolveUsesUserDefaultsWhenEnvironmentIsMissing() {
        userDefaults.set("native", forKey: MeetingNotesEditorEngineResolver.userDefaultsKey)
        let resolver = makeResolver(environment: [:])

        XCTAssertEqual(resolver.resolve(), .native)
    }

    func testResolveEnvironmentOverridesUserDefaults() {
        userDefaults.set("native", forKey: MeetingNotesEditorEngineResolver.userDefaultsKey)
        let resolver = makeResolver(environment: [MeetingNotesEditorEngineResolver.environmentKey: "textual"])

        XCTAssertEqual(resolver.resolve(), .textual)
    }

    private func makeResolver(environment: [String: String]) -> MeetingNotesEditorEngineResolver {
        MeetingNotesEditorEngineResolver(
            environmentProvider: { environment },
            userDefaults: userDefaults
        )
    }
}
