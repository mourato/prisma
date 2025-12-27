import Foundation
import os.log

/// Centralized logger for the application using os.log
public enum AppLogger {
    private static let subsystem = "com.meetingassistant.app"

    // Cache loggers to avoid recreating them
    private static var loggers: [LogCategory: Logger] = [:]
    private static let lock = NSLock()

    private static func getLogger(for category: LogCategory) -> Logger {
        self.lock.lock()
        defer { lock.unlock() }

        if let existing = loggers[category] {
            return existing
        }

        let newLogger = Logger(subsystem: subsystem, category: category.rawValue)
        self.loggers[category] = newLogger
        return newLogger
    }

    // MARK: - Public API

    /// Log a debug message (development only)
    public static func debug(_ message: String, category: LogCategory, extra: [String: Any]? = nil) {
        let logger = self.getLogger(for: category)
        let formattedMessage = self.format(message, extra: extra)
        logger.debug("\(formattedMessage, privacy: .public)")
    }

    /// Log an informational message (general events)
    public static func info(_ message: String, category: LogCategory, extra: [String: Any]? = nil) {
        let logger = self.getLogger(for: category)
        let formattedMessage = self.format(message, extra: extra)
        logger.info("\(formattedMessage, privacy: .public)")
    }

    /// Log an error (recoverable issues)
    public static func error(_ message: String, category: LogCategory, error: Error? = nil, extra: [String: Any]? = nil) {
        let logger = self.getLogger(for: category)
        var detailedMessage = message

        if let error {
            detailedMessage += " | Error: \(error.localizedDescription)"
        }

        let formattedMessage = self.format(detailedMessage, extra: extra)
        logger.error("\(formattedMessage, privacy: .public)")
    }

    /// Log a fault (critical issues/crashes)
    public static func fault(_ message: String, category: LogCategory, extra: [String: Any]? = nil) {
        let logger = self.getLogger(for: category)
        let formattedMessage = self.format(message, extra: extra)
        logger.fault("\(formattedMessage, privacy: .public)")
    }

    // MARK: - Private Helpers

    private static func format(_ message: String, extra: [String: Any]?) -> String {
        guard let extra, !extra.isEmpty else {
            return message
        }

        let extraString = extra.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return "\(message) [\(extraString)]"
    }
}
