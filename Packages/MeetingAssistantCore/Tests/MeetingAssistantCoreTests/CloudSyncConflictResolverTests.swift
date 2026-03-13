import XCTest
@testable import MeetingAssistantCore

final class CloudSyncConflictResolverTests: XCTestCase {
    func testDecide_ReturnsIdenticalWhenHashesMatch() {
        let decision = CloudSyncConflictResolver.decide(
            localUpdatedAtMillis: 100,
            localSourceDeviceID: "A",
            localHash: "same",
            remoteUpdatedAtMillis: 200,
            remoteSourceDeviceID: "B",
            remoteHash: "same"
        )

        XCTAssertEqual(decision, .identical)
    }

    func testDecide_ReturnsRemoteWinsWhenRemoteTimestampIsGreater() {
        let decision = CloudSyncConflictResolver.decide(
            localUpdatedAtMillis: 100,
            localSourceDeviceID: "A",
            localHash: "local",
            remoteUpdatedAtMillis: 200,
            remoteSourceDeviceID: "B",
            remoteHash: "remote"
        )

        XCTAssertEqual(decision, .remoteWins)
    }

    func testDecide_UsesSourceDeviceIDAsTieBreaker() {
        let decision = CloudSyncConflictResolver.decide(
            localUpdatedAtMillis: 100,
            localSourceDeviceID: "device-a",
            localHash: "local",
            remoteUpdatedAtMillis: 100,
            remoteSourceDeviceID: "device-z",
            remoteHash: "remote"
        )

        XCTAssertEqual(decision, .remoteWins)
    }
}
