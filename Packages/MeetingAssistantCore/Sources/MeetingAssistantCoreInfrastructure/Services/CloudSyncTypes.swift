import CryptoKit
import Foundation
import MeetingAssistantCoreCommon

public enum CloudSyncSource: Sendable {
    case local
    case cloud
}

public enum CloudSyncConflictDecision: Equatable, Sendable {
    case localWins
    case remoteWins
    case identical
}

public enum CloudSyncRecordType {
    public static let settingsV1 = "PrismaSettingsV1"
    public static let meetingNoteV1 = "PrismaMeetingNoteV1"
    public static let settingsRecordName = "settings_v1"

    public static func meetingNoteRecordName(meetingID: UUID) -> String {
        "meeting_note_\(meetingID.uuidString)"
    }
}

public enum CloudSyncHashing {
    public static func sha256Hex(_ value: Data) -> String {
        let digest = SHA256.hash(data: value)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256Hex(_ value: String) -> String {
        sha256Hex(Data(value.utf8))
    }
}

public enum CloudSyncConflictResolver {
    public static func decide(
        localUpdatedAtMillis: Int64,
        localSourceDeviceID: String,
        localHash: String,
        remoteUpdatedAtMillis: Int64,
        remoteSourceDeviceID: String,
        remoteHash: String
    ) -> CloudSyncConflictDecision {
        if localHash == remoteHash {
            return .identical
        }

        if remoteUpdatedAtMillis > localUpdatedAtMillis {
            return .remoteWins
        }

        if remoteUpdatedAtMillis < localUpdatedAtMillis {
            return .localWins
        }

        if remoteSourceDeviceID > localSourceDeviceID {
            return .remoteWins
        }

        return .localWins
    }
}

public enum CloudSyncDeviceIdentity {
    public static func current(userDefaults: UserDefaults = .standard) -> String {
        if let existing = userDefaults.string(forKey: AppIdentity.cloudSyncDeviceIdentifierUserDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !existing.isEmpty
        {
            return existing
        }

        let generated = UUID().uuidString
        userDefaults.set(generated, forKey: AppIdentity.cloudSyncDeviceIdentifierUserDefaultsKey)
        return generated
    }
}

public struct CloudSyncSettingsSnapshotV1: Codable, Hashable, Sendable {
    public static let schemaVersion: Int64 = 1

    public let schemaVersion: Int64
    public let payloadJSON: Data
    public let updatedAtMillis: Int64
    public let sourceDeviceID: String
    public let payloadHash: String

    public init(
        schemaVersion: Int64 = Self.schemaVersion,
        payloadJSON: Data,
        updatedAtMillis: Int64,
        sourceDeviceID: String,
        payloadHash: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.payloadJSON = payloadJSON
        self.updatedAtMillis = updatedAtMillis
        self.sourceDeviceID = sourceDeviceID
        self.payloadHash = payloadHash ?? CloudSyncHashing.sha256Hex(payloadJSON)
    }
}

public struct CloudMeetingNoteSnapshotV1: Codable, Hashable, Sendable {
    public static let schemaVersion: Int64 = 1

    public let schemaVersion: Int64
    public let meetingID: UUID
    public let markdownBody: String
    public let updatedAtMillis: Int64
    public let sourceDeviceID: String
    public let contentHash: String

    public init(
        schemaVersion: Int64 = Self.schemaVersion,
        meetingID: UUID,
        markdownBody: String,
        updatedAtMillis: Int64,
        sourceDeviceID: String,
        contentHash: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.meetingID = meetingID
        self.markdownBody = markdownBody
        self.updatedAtMillis = updatedAtMillis
        self.sourceDeviceID = sourceDeviceID
        self.contentHash = contentHash ?? CloudSyncHashing.sha256Hex(markdownBody)
    }
}
