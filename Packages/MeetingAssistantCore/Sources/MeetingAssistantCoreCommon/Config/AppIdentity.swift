import Foundation

/// Centralized runtime identity values used across app and core modules.
public enum AppIdentity {
    public static let displayName = "Prisma"
    public static let bundleIdentifier = "com.mourato.prisma"
    public static let xpcServiceName = "com.mourato.prisma.ai-service"
    public static let logSubsystem = "com.mourato.prisma"
    public static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    // Keep these identifiers stable to preserve existing window toolbar/autosave state.
    public static let settingsToolbarIdentifier = "MeetingAssistantSettingsToolbar"
    public static let settingsWindowAutosaveName = "MeetingAssistantSettingsWindow"

    public static let appSupportDirectoryName = "Prisma"
    public static let logDirectoryName = "Prisma"
    public static let keychainServiceIdentifier = "com.mourato.prisma"
    public static let hotkeySignatureSeed = "PRH0"

    public static let legacyUserDefaultsDomain = "com.meetingassistant.app"
    public static let userDefaultsDomainMigrationFlag = "migrations.user_defaults_domain.v1"

    public static let legacyAppSupportDirectoryName = "MeetingAssistant"
    public static let legacyLogDirectoryName = "MeetingAssistant"

    public static let legacyKeychainServiceIdentifiers = ["com.meeting-assistant"]
    public static let cloudKitContainerIdentifier = "iCloud.com.mourato.prisma"
    public static let cloudSyncDeviceIdentifierUserDefaultsKey = "cloud.sync.device_identifier.v1"

    public static func appSupportBaseDirectory(fileManager: FileManager = .default) -> URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let currentURL = appSupportURL.appendingPathComponent(appSupportDirectoryName, isDirectory: true)
        let legacyURL = appSupportURL.appendingPathComponent(legacyAppSupportDirectoryName, isDirectory: true)
        migrateLegacyDirectoryIfNeeded(from: legacyURL, to: currentURL, fileManager: fileManager)
        if fileManager.fileExists(atPath: currentURL.path) {
            return currentURL
        }
        if fileManager.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }
        return currentURL
    }

    public static func logsBaseDirectory(fileManager: FileManager = .default) -> URL {
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let logsRootURL = libraryURL.appendingPathComponent("Logs", isDirectory: true)
        let currentURL = logsRootURL.appendingPathComponent(logDirectoryName, isDirectory: true)
        let legacyURL = logsRootURL.appendingPathComponent(legacyLogDirectoryName, isDirectory: true)
        migrateLegacyDirectoryIfNeeded(from: legacyURL, to: currentURL, fileManager: fileManager)
        if fileManager.fileExists(atPath: currentURL.path) {
            return currentURL
        }
        if fileManager.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }
        return currentURL
    }

    private static func migrateLegacyDirectoryIfNeeded(from legacyURL: URL, to currentURL: URL, fileManager: FileManager) {
        guard fileManager.fileExists(atPath: legacyURL.path),
              !fileManager.fileExists(atPath: currentURL.path)
        else {
            return
        }

        do {
            try fileManager.moveItem(at: legacyURL, to: currentURL)
        } catch {
            // Keep fallback behavior in callers when migration fails.
        }
    }
}
