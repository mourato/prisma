import Foundation
import os.log

/// Manages crash reporting and logging of uncaught exceptions to disk
public final class CrashReporter: Sendable {
    public static let shared = CrashReporter()

    private let logDirectory: URL

    private init() {
        // Setup logs directory: ~/Library/Logs/MeetingAssistant/CrashReports
        let fileManager = FileManager.default
        // Safe unwrap with fallback to temporary directory if library is unavailable (unlikely)
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let logsURL = libraryURL.appendingPathComponent("Logs/MeetingAssistant/CrashReports")
        self.logDirectory = logsURL

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true, attributes: nil)
    }

    /// Installs the uncaught exception handler
    public func setup() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }

        // Signal handlers are tricky in Swift and often conflict with LLDB.
        // We rely on macOS system crash reporter for signals (SIGSEGV, SIGABRT)
        // and this handler for NSExceptions (Objective-C exceptions, forced unwraps in mixed code).

        AppLogger.info("CrashReporter installed. Logs at: \(self.logDirectory.path)", category: .health)
    }

    private func handleException(_ exception: NSException) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "crash-\(timestamp).log"
        let fileURL = self.logDirectory.appendingPathComponent(filename)

        let report = """
        CRASH REPORT - \(timestamp)
        ======================================================================
        Name: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "Unknown")

        Stack Trace:
        \(exception.callStackSymbols.joined(separator: "\n"))

        User Info:
        \(exception.userInfo?.description ?? "None")
        ======================================================================
        """

        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            // Log to system as well
            AppLogger.fault("App Crashed! Saved report to \(fileURL.lastPathComponent)", category: .health)
        } catch {
            print("Failed to write crash report: \(error)")
        }
    }

    /// Performs any necessary cleanup before application termination
    public func cleanup() {
        // Currently just log, as NSSetUncaughtExceptionHandler doesn't need explicit removal
        AppLogger.debug("CrashReporter cleanup completed", category: .health)
    }
}
