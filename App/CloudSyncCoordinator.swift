import Foundation
import MeetingAssistantCore

struct CloudSyncPullResult {
    let settingsSnapshotToApply: CloudSyncSettingsSnapshotV1?
    let meetingNoteSnapshotsToApply: [CloudMeetingNoteSnapshotV1]

    static let empty = CloudSyncPullResult(settingsSnapshotToApply: nil, meetingNoteSnapshotsToApply: [])
}

actor CloudSyncCoordinator {
    private enum MetadataKeys {
        static let settingsHash = "cloud.sync.settings.local_hash.v1"
        static let settingsUpdatedAtMillis = "cloud.sync.settings.local_updated_at_millis.v1"
    }

    private let settingsService: any CloudSettingsSyncServiceProtocol
    private let meetingNotesService: any CloudMeetingNotesSyncServiceProtocol
    private let userDefaults: UserDefaults
    private let deviceID: String

    private var settingsPushTask: Task<Void, Never>?
    private var meetingNotesPushTasks: [UUID: Task<Void, Never>] = [:]
    private var suppressSettingsPushUntilMillis: Int64 = 0

    init(
        settingsService: any CloudSettingsSyncServiceProtocol = CloudSettingsSyncService(),
        meetingNotesService: any CloudMeetingNotesSyncServiceProtocol = CloudMeetingNotesSyncService(),
        userDefaults: UserDefaults = .standard,
        deviceID: String = CloudSyncDeviceIdentity.current()
    ) {
        self.settingsService = settingsService
        self.meetingNotesService = meetingNotesService
        self.userDefaults = userDefaults
        self.deviceID = deviceID
    }

    deinit {
        settingsPushTask?.cancel()
        meetingNotesPushTasks.values.forEach { $0.cancel() }
    }

    func bootstrap(
        localSettingsSnapshot: CloudSyncSettingsSnapshotV1,
        localMeetingNotes: [CloudMeetingNoteSnapshotV1]
    ) async -> CloudSyncPullResult {
        await refresh(
            localSettingsSnapshot: localSettingsSnapshot,
            localMeetingNotes: localMeetingNotes
        )
    }

    func refresh(
        localSettingsSnapshot: CloudSyncSettingsSnapshotV1,
        localMeetingNotes: [CloudMeetingNoteSnapshotV1]
    ) async -> CloudSyncPullResult {
        async let settingsResolution = resolveSettings(localSnapshot: localSettingsSnapshot)
        async let meetingNotesResolution = resolveMeetingNotes(localSnapshots: localMeetingNotes)

        let settingsSnapshotToApply = await settingsResolution
        let meetingNoteSnapshotsToApply = await meetingNotesResolution

        return CloudSyncPullResult(
            settingsSnapshotToApply: settingsSnapshotToApply,
            meetingNoteSnapshotsToApply: meetingNoteSnapshotsToApply
        )
    }

    func scheduleSettingsPush(localSnapshot: CloudSyncSettingsSnapshotV1) {
        let nowMillis = Self.nowMillis()
        guard nowMillis >= suppressSettingsPushUntilMillis else { return }

        let normalizedSnapshot = normalizedLocalSettingsSnapshot(from: localSnapshot)
        settingsPushTask?.cancel()
        settingsPushTask = Task { [settingsService] in
            try? await Task.sleep(for: .milliseconds(500))
            do {
                try await settingsService.upsertRemoteSnapshot(normalizedSnapshot)
                AppLogger.info(
                    "Cloud settings push completed",
                    category: .storage,
                    extra: [
                        "updatedAtMillis": normalizedSnapshot.updatedAtMillis,
                        "payloadHash": normalizedSnapshot.payloadHash,
                    ]
                )
            } catch {
                AppLogger.error("Cloud settings push failed", category: .storage, error: error)
            }
        }
    }

    func scheduleMeetingNotePush(localSnapshot: CloudMeetingNoteSnapshotV1) {
        meetingNotesPushTasks[localSnapshot.meetingID]?.cancel()
        meetingNotesPushTasks[localSnapshot.meetingID] = Task { [meetingNotesService] in
            try? await Task.sleep(for: .milliseconds(350))
            do {
                try await meetingNotesService.upsertRemoteNote(localSnapshot)
                AppLogger.info(
                    "Cloud meeting note push completed",
                    category: .storage,
                    extra: [
                        "meetingID": localSnapshot.meetingID.uuidString,
                        "updatedAtMillis": localSnapshot.updatedAtMillis,
                        "contentHash": localSnapshot.contentHash,
                    ]
                )
            } catch {
                AppLogger.error(
                    "Cloud meeting note push failed",
                    category: .storage,
                    error: error,
                    extra: ["meetingID": localSnapshot.meetingID.uuidString]
                )
            }
        }
    }

    private func resolveSettings(localSnapshot: CloudSyncSettingsSnapshotV1) async -> CloudSyncSettingsSnapshotV1? {
        let normalizedLocalSnapshot = normalizedLocalSettingsSnapshot(from: localSnapshot)

        let remoteSnapshot: CloudSyncSettingsSnapshotV1?
        do {
            remoteSnapshot = try await settingsService.fetchRemoteSnapshot()
        } catch {
            AppLogger.error("Cloud settings pull failed", category: .storage, error: error)
            return nil
        }

        guard let remoteSnapshot else {
            do {
                try await settingsService.upsertRemoteSnapshot(normalizedLocalSnapshot)
            } catch {
                AppLogger.error("Cloud settings bootstrap push failed", category: .storage, error: error)
            }
            return nil
        }

        let decision = CloudSyncConflictResolver.decide(
            localUpdatedAtMillis: normalizedLocalSnapshot.updatedAtMillis,
            localSourceDeviceID: normalizedLocalSnapshot.sourceDeviceID,
            localHash: normalizedLocalSnapshot.payloadHash,
            remoteUpdatedAtMillis: remoteSnapshot.updatedAtMillis,
            remoteSourceDeviceID: remoteSnapshot.sourceDeviceID,
            remoteHash: remoteSnapshot.payloadHash
        )

        switch decision {
        case .identical:
            AppLogger.info(
                "Cloud settings reconcile identical",
                category: .storage,
                extra: ["payloadHash": remoteSnapshot.payloadHash]
            )
            persistSettingsMetadata(hash: remoteSnapshot.payloadHash, updatedAtMillis: remoteSnapshot.updatedAtMillis)
            return nil
        case .localWins:
            AppLogger.info(
                "Cloud settings reconcile local wins",
                category: .storage,
                extra: [
                    "localUpdatedAtMillis": normalizedLocalSnapshot.updatedAtMillis,
                    "remoteUpdatedAtMillis": remoteSnapshot.updatedAtMillis,
                ]
            )
            do {
                try await settingsService.upsertRemoteSnapshot(normalizedLocalSnapshot)
            } catch {
                AppLogger.error("Cloud settings reconcile push failed", category: .storage, error: error)
            }
            return nil
        case .remoteWins:
            AppLogger.info(
                "Cloud settings reconcile remote wins",
                category: .storage,
                extra: [
                    "localUpdatedAtMillis": normalizedLocalSnapshot.updatedAtMillis,
                    "remoteUpdatedAtMillis": remoteSnapshot.updatedAtMillis,
                ]
            )
            persistSettingsMetadata(hash: remoteSnapshot.payloadHash, updatedAtMillis: remoteSnapshot.updatedAtMillis)
            suppressSettingsPushUntilMillis = Self.nowMillis() + 1_500
            return remoteSnapshot
        }
    }

    private func resolveMeetingNotes(localSnapshots: [CloudMeetingNoteSnapshotV1]) async -> [CloudMeetingNoteSnapshotV1] {
        let remoteSnapshots: [CloudMeetingNoteSnapshotV1]
        do {
            remoteSnapshots = try await meetingNotesService.fetchAllRemoteNotes()
        } catch {
            AppLogger.error("Cloud meeting notes pull failed", category: .storage, error: error)
            return []
        }

        let localByMeetingID = Dictionary(uniqueKeysWithValues: localSnapshots.map { ($0.meetingID, $0) })
        let remoteByMeetingID = Dictionary(uniqueKeysWithValues: remoteSnapshots.map { ($0.meetingID, $0) })
        let allMeetingIDs = Set(localByMeetingID.keys).union(remoteByMeetingID.keys)

        var snapshotsToApply: [CloudMeetingNoteSnapshotV1] = []
        snapshotsToApply.reserveCapacity(allMeetingIDs.count)
        var localWinsCount = 0
        var remoteWinsCount = 0
        var identicalCount = 0

        for meetingID in allMeetingIDs {
            let local = localByMeetingID[meetingID]
            let remote = remoteByMeetingID[meetingID]

            switch (local, remote) {
            case let (local?, nil):
                do {
                    try await meetingNotesService.upsertRemoteNote(local)
                } catch {
                    AppLogger.error(
                        "Cloud meeting note bootstrap push failed",
                        category: .storage,
                        error: error,
                        extra: ["meetingID": local.meetingID.uuidString]
                    )
                }
            case let (nil, remote?):
                snapshotsToApply.append(remote)
            case let (local?, remote?):
                let decision = CloudSyncConflictResolver.decide(
                    localUpdatedAtMillis: local.updatedAtMillis,
                    localSourceDeviceID: local.sourceDeviceID,
                    localHash: local.contentHash,
                    remoteUpdatedAtMillis: remote.updatedAtMillis,
                    remoteSourceDeviceID: remote.sourceDeviceID,
                    remoteHash: remote.contentHash
                )

                switch decision {
                case .identical:
                    identicalCount += 1
                    continue
                case .localWins:
                    localWinsCount += 1
                    do {
                        try await meetingNotesService.upsertRemoteNote(local)
                    } catch {
                        AppLogger.error(
                            "Cloud meeting note reconcile push failed",
                            category: .storage,
                            error: error,
                            extra: ["meetingID": local.meetingID.uuidString]
                        )
                    }
                case .remoteWins:
                    remoteWinsCount += 1
                    snapshotsToApply.append(remote)
                }
            case (nil, nil):
                continue
            }
        }

        AppLogger.info(
            "Cloud meeting notes reconcile completed",
            category: .storage,
            extra: [
                "localCount": localSnapshots.count,
                "remoteCount": remoteSnapshots.count,
                "applyCount": snapshotsToApply.count,
                "localWins": localWinsCount,
                "remoteWins": remoteWinsCount,
                "identical": identicalCount,
            ]
        )

        return snapshotsToApply.sorted { lhs, rhs in
            if lhs.updatedAtMillis != rhs.updatedAtMillis {
                return lhs.updatedAtMillis < rhs.updatedAtMillis
            }
            return lhs.meetingID.uuidString < rhs.meetingID.uuidString
        }
    }

    private func normalizedLocalSettingsSnapshot(from snapshot: CloudSyncSettingsSnapshotV1) -> CloudSyncSettingsSnapshotV1 {
        let currentHash = snapshot.payloadHash
        let storedHash = userDefaults.string(forKey: MetadataKeys.settingsHash)
        let storedUpdatedAtMillis = userDefaults.object(forKey: MetadataKeys.settingsUpdatedAtMillis) as? Int64 ?? 0

        let updatedAtMillis: Int64
        if storedHash == currentHash, storedUpdatedAtMillis > 0 {
            updatedAtMillis = storedUpdatedAtMillis
        } else {
            updatedAtMillis = Self.nowMillis()
            persistSettingsMetadata(hash: currentHash, updatedAtMillis: updatedAtMillis)
        }

        return CloudSyncSettingsSnapshotV1(
            schemaVersion: snapshot.schemaVersion,
            payloadJSON: snapshot.payloadJSON,
            updatedAtMillis: updatedAtMillis,
            sourceDeviceID: deviceID,
            payloadHash: currentHash
        )
    }

    private func persistSettingsMetadata(hash: String, updatedAtMillis: Int64) {
        userDefaults.set(hash, forKey: MetadataKeys.settingsHash)
        userDefaults.set(updatedAtMillis, forKey: MetadataKeys.settingsUpdatedAtMillis)
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000.0)
    }
}
