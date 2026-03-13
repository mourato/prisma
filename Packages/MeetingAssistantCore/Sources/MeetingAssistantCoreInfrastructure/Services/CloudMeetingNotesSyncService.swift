import CloudKit
import Foundation
import MeetingAssistantCoreCommon

public protocol CloudMeetingNotesSyncServiceProtocol: Sendable {
    func fetchAllRemoteNotes() async throws -> [CloudMeetingNoteSnapshotV1]
    func upsertRemoteNote(_ snapshot: CloudMeetingNoteSnapshotV1) async throws
}

public enum CloudMeetingNotesSyncServiceError: LocalizedError {
    case invalidRecord

    public var errorDescription: String? {
        switch self {
        case .invalidRecord:
            "Invalid CloudKit meeting note record payload."
        }
    }
}

public actor CloudMeetingNotesSyncService: CloudMeetingNotesSyncServiceProtocol {
    private let database: CKDatabase

    public init(
        containerIdentifier: String = AppIdentity.cloudKitContainerIdentifier,
        container: CKContainer? = nil
    ) {
        let resolvedContainer = container ?? CKContainer(identifier: containerIdentifier)
        database = resolvedContainer.privateCloudDatabase
    }

    public func fetchAllRemoteNotes() async throws -> [CloudMeetingNoteSnapshotV1] {
        let records = try await fetchAllRecords()
        return try records.map(snapshot(from:))
    }

    public func upsertRemoteNote(_ snapshot: CloudMeetingNoteSnapshotV1) async throws {
        let recordID = CKRecord.ID(recordName: CloudSyncRecordType.meetingNoteRecordName(meetingID: snapshot.meetingID))
        let record = CKRecord(recordType: CloudSyncRecordType.meetingNoteV1, recordID: recordID)
        record["schemaVersion"] = NSNumber(value: snapshot.schemaVersion)
        record["meetingID"] = snapshot.meetingID.uuidString as NSString
        record["markdownBody"] = snapshot.markdownBody as NSString
        record["updatedAtMillis"] = NSNumber(value: snapshot.updatedAtMillis)
        record["sourceDeviceID"] = snapshot.sourceDeviceID as NSString
        record["contentHash"] = snapshot.contentHash as NSString
        _ = try await database.save(record)
    }

    private func snapshot(from record: CKRecord) throws -> CloudMeetingNoteSnapshotV1 {
        guard let schemaVersionNumber = record["schemaVersion"] as? NSNumber,
              let meetingIDRaw = record["meetingID"] as? String,
              let meetingID = UUID(uuidString: meetingIDRaw),
              let markdownBody = record["markdownBody"] as? String,
              let updatedAtMillisNumber = record["updatedAtMillis"] as? NSNumber,
              let sourceDeviceID = record["sourceDeviceID"] as? String,
              let contentHash = record["contentHash"] as? String
        else {
            throw CloudMeetingNotesSyncServiceError.invalidRecord
        }

        return CloudMeetingNoteSnapshotV1(
            schemaVersion: schemaVersionNumber.int64Value,
            meetingID: meetingID,
            markdownBody: markdownBody,
            updatedAtMillis: updatedAtMillisNumber.int64Value,
            sourceDeviceID: sourceDeviceID,
            contentHash: contentHash
        )
    }

    private func fetchAllRecords() async throws -> [CKRecord] {
        let query = CKQuery(recordType: CloudSyncRecordType.meetingNoteV1, predicate: NSPredicate(value: true))
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page = try await fetchPage(query: query, cursor: cursor)
            allRecords.append(contentsOf: page.records)
            cursor = page.cursor
        } while cursor != nil

        return allRecords
    }

    private func fetchPage(
        query: CKQuery,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation = if let cursor {
                CKQueryOperation(cursor: cursor)
            } else {
                CKQueryOperation(query: query)
            }

            operation.desiredKeys = [
                "schemaVersion",
                "meetingID",
                "markdownBody",
                "updatedAtMillis",
                "sourceDeviceID",
                "contentHash",
            ]

            var fetchedRecords: [CKRecord] = []
            var firstError: Error?

            operation.recordMatchedBlock = { _, result in
                switch result {
                case let .success(record):
                    fetchedRecords.append(record)
                case let .failure(error):
                    if firstError == nil {
                        firstError = error
                    }
                }
            }

            operation.queryResultBlock = { result in
                if let firstError {
                    continuation.resume(throwing: firstError)
                    return
                }

                switch result {
                case let .success(nextCursor):
                    continuation.resume(returning: (records: fetchedRecords, cursor: nextCursor))
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }
}
