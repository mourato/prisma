import CloudKit
import Foundation
import MeetingAssistantCoreCommon

public protocol CloudSettingsSyncServiceProtocol: Sendable {
    func fetchRemoteSnapshot() async throws -> CloudSyncSettingsSnapshotV1?
    func upsertRemoteSnapshot(_ snapshot: CloudSyncSettingsSnapshotV1) async throws
}

public enum CloudSettingsSyncServiceError: LocalizedError {
    case invalidRecord

    public var errorDescription: String? {
        switch self {
        case .invalidRecord:
            "Invalid CloudKit settings record payload."
        }
    }
}

public actor CloudSettingsSyncService: CloudSettingsSyncServiceProtocol {
    private let database: CKDatabase

    public init(
        containerIdentifier: String = AppIdentity.cloudKitContainerIdentifier,
        container: CKContainer? = nil
    ) {
        let resolvedContainer = container ?? CKContainer(identifier: containerIdentifier)
        database = resolvedContainer.privateCloudDatabase
    }

    public func fetchRemoteSnapshot() async throws -> CloudSyncSettingsSnapshotV1? {
        do {
            let record = try await database.record(for: settingsRecordID)
            return try snapshot(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw error
        }
    }

    public func upsertRemoteSnapshot(_ snapshot: CloudSyncSettingsSnapshotV1) async throws {
        let record = CKRecord(recordType: CloudSyncRecordType.settingsV1, recordID: settingsRecordID)
        record["schemaVersion"] = NSNumber(value: snapshot.schemaVersion)
        record["payloadJSON"] = snapshot.payloadJSON as NSData
        record["updatedAtMillis"] = NSNumber(value: snapshot.updatedAtMillis)
        record["sourceDeviceID"] = snapshot.sourceDeviceID as NSString
        record["payloadHash"] = snapshot.payloadHash as NSString
        _ = try await database.save(record)
    }

    private var settingsRecordID: CKRecord.ID {
        CKRecord.ID(recordName: CloudSyncRecordType.settingsRecordName)
    }

    private func snapshot(from record: CKRecord) throws -> CloudSyncSettingsSnapshotV1 {
        guard let schemaVersionNumber = record["schemaVersion"] as? NSNumber,
              let payloadJSON = record["payloadJSON"] as? Data,
              let updatedAtMillisNumber = record["updatedAtMillis"] as? NSNumber,
              let sourceDeviceID = record["sourceDeviceID"] as? String,
              let payloadHash = record["payloadHash"] as? String
        else {
            throw CloudSettingsSyncServiceError.invalidRecord
        }

        return CloudSyncSettingsSnapshotV1(
            schemaVersion: schemaVersionNumber.int64Value,
            payloadJSON: payloadJSON,
            updatedAtMillis: updatedAtMillisNumber.int64Value,
            sourceDeviceID: sourceDeviceID,
            payloadHash: payloadHash
        )
    }
}
