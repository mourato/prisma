import AppKit
import Combine
import Foundation
import MeetingAssistantCoreDomain
import os.log

/// Service for detecting active meetings from supported apps.
/// Monitors running applications and window titles.
@MainActor
public class MeetingDetector: ObservableObject {
    public static let shared = MeetingDetector()

    private let logger = Logger(subsystem: "MeetingAssistant", category: "MeetingDetector")

    @Published public private(set) var detectedMeeting: MeetingApp?
    @Published private(set) var isMonitoring = false

    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// Poll interval in seconds
    private let pollInterval: TimeInterval = 2.0

    private init() {
        setupAppNotifications()
    }

    /// Start monitoring for meeting apps.
    public func startMonitoring() {
        guard !isMonitoring else { return }

        logger.info("Starting meeting detection monitoring")
        isMonitoring = true

        // Initial check
        checkForMeetings()

        // Periodic polling
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkForMeetings()
            }
        }
    }

    /// Stop monitoring for meeting apps.
    func stopMonitoring() {
        logger.info("Stopping meeting detection monitoring")
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        detectedMeeting = nil
    }

    /// Check currently running apps for active meetings.
    private func checkForMeetings() {
        let runningApps = NSWorkspace.shared.runningApplications

        for meetingApp in MeetingApp.allCases where isMeetingActive(meetingApp, in: runningApps) {
            if self.detectedMeeting != meetingApp {
                self.logger.info("Detected meeting: \(meetingApp.displayName)")
                self.detectedMeeting = meetingApp
            }
            return
        }

        // No meeting detected
        if detectedMeeting != nil {
            logger.info("Meeting ended")
            detectedMeeting = nil
        }
    }

    /// Check if a specific meeting app has an active meeting.
    private func isMeetingActive(_ app: MeetingApp, in runningApps: [NSRunningApplication]) -> Bool {
        // Find matching running app
        let matchingApps = runningApps.filter { runningApp in
            guard let bundleId = runningApp.bundleIdentifier else { return false }
            return app.bundleIdentifiers.contains(bundleId)
        }

        guard !matchingApps.isEmpty else { return false }

        // For browser-based meetings, check window titles
        if app == .googleMeet {
            return checkBrowserWindowTitles(for: app.windowTitlePatterns)
        }

        // For native apps, just check if running
        // More sophisticated detection could check window titles
        return true
    }

    /// Check browser window titles for meeting indicators.
    private func checkBrowserWindowTitles(for patterns: [String]) -> Bool {
        // Get window list
        let windowInfoOptions: CGWindowListOption = [.optionOnScreenOnly]
        guard
            let windowList = CGWindowListCopyWindowInfo(
                windowInfoOptions,
                kCGNullWindowID
            ) as? [[CFString: Any]]
        else {
            return false
        }

        for window in windowList {
            guard let windowName = window[kCGWindowName] as? String else { continue }

            for pattern in patterns where windowName.localizedCaseInsensitiveContains(pattern) {
                self.logger.debug("Found matching window: \(windowName)")
                return true
            }
        }

        return false
    }

    /// Setup notifications for app launches/terminations.
    private func setupAppNotifications() {
        let workspace = NSWorkspace.shared

        // App launched
        workspace.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] notification in
                let appInfo = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                guard let app = appInfo as? NSRunningApplication else { return }
                self?.logger.debug("App launched: \(app.bundleIdentifier ?? "unknown")")
                Task { @MainActor in
                    self?.checkForMeetings()
                }
            }
            .store(in: &cancellables)

        // App terminated
        workspace.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] notification in
                let appInfo = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                guard let app = appInfo as? NSRunningApplication else { return }
                self?.logger.debug("App terminated: \(app.bundleIdentifier ?? "unknown")")
                Task { @MainActor in
                    self?.checkForMeetings()
                }
            }
            .store(in: &cancellables)
    }
}
