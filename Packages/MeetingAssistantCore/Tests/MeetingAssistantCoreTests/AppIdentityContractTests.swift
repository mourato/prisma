import Foundation
@testable import MeetingAssistantCore
import XCTest

final class AppIdentityContractTests: XCTestCase {
    func testVisibleBrandAndProtectedIdentifiers() {
        XCTAssertEqual(AppIdentity.displayName, "Vozinha")
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.mourato.prisma")
        XCTAssertEqual(AppIdentity.xpcServiceName, "com.mourato.prisma.ai-service")
        XCTAssertEqual(AppIdentity.appSupportDirectoryName, "Prisma")
        XCTAssertEqual(AppIdentity.logDirectoryName, "Prisma")
        XCTAssertEqual(AppIdentity.keychainServiceIdentifier, "com.mourato.prisma")
        XCTAssertEqual(AppIdentity.legacyAppSupportDirectoryName, "MeetingAssistant")
        XCTAssertEqual(AppIdentity.legacyLogDirectoryName, "MeetingAssistant")
        XCTAssertEqual(AppIdentity.legacyKeychainServiceIdentifiers, ["com.meeting-assistant"])
        XCTAssertEqual(AppIdentity.settingsToolbarIdentifier, "MeetingAssistantSettingsToolbar")
        XCTAssertEqual(AppIdentity.settingsWindowAutosaveName, "MeetingAssistantSettingsWindow")
    }

    func testManifestUsesPropertyListSections() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Config/AppIdentity.plist")
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            XCTFail("Manifest must contain a property-list dictionary")
            return
        }
        XCTAssertEqual(Set(plist.keys), ["product", "technical", "persistence", "migration", "internal"])
    }
}
