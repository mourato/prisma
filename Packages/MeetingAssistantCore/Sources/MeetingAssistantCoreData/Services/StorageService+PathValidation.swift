import Foundation
import MeetingAssistantCoreCommon

extension FileSystemStorageService {
    // MARK: - Path Validation

    enum PathValidationError: Error, LocalizedError {
        case pathTraversalDetected(String)
        case invalidPath(String)
        case outsideContainer(String)

        var errorDescription: String? {
            switch self {
            case let .pathTraversalDetected(path):
                "Security: Path traversal attempt detected - \(path)"
            case let .invalidPath(path):
                "Security: Invalid path format - \(path)"
            case let .outsideContainer(path):
                "Security: Path outside app container - \(path)"
            }
        }
    }

    /// Validates that a path is safe and within the app container.
    func validatePath(_ path: String) throws -> URL {
        do {
            try InputSanitizer.validatePathComponent(path)
        } catch {
            AppLogger.warning("Path traversal attempt blocked", category: .databaseManager, extra: ["path": path])
            throw PathValidationError.pathTraversalDetected(path)
        }

        let url = URL(fileURLWithPath: path)
        let resolvedPath = url.resolvingSymlinksInPath().path

        let containerPath = AppIdentity.appSupportBaseDirectory(fileManager: .default).path
        let appSupportRootURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let legacyContainerPath = appSupportRootURL
            .appendingPathComponent(AppIdentity.legacyAppSupportDirectoryName, isDirectory: true)
            .path
        let isInsideKnownContainer = resolvedPath.hasPrefix(containerPath) || resolvedPath.hasPrefix(legacyContainerPath)
        guard isInsideKnownContainer else {
            AppLogger.warning("Path outside container blocked", category: .databaseManager, extra: [
                "path": path,
                "resolved": resolvedPath,
                "container": containerPath,
            ])
            throw PathValidationError.outsideContainer(path)
        }

        return URL(fileURLWithPath: resolvedPath)
    }
}
