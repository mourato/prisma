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
    private let settings: AppSettingsStore
    private let browserProviders: [String: BrowserActiveTabURLProviding]

    @Published public private(set) var detectedMeeting: MeetingApp?
    @Published private(set) var isMonitoring = false

    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// Poll interval in seconds
    private let pollInterval: TimeInterval = 2.0

    private init(settings: AppSettingsStore = .shared) {
        self.settings = settings
        self.browserProviders = BrowserProviderRegistry.defaultProviders()
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
        let monitoredBundleIdentifiers = normalizedMonitoredBundleIdentifiers()

        if let webMatch = detectWebMeeting(in: runningApps, monitoredBundleIdentifiers: monitoredBundleIdentifiers) {
            if detectedMeeting != webMatch {
                logger.info("Detected web meeting: \(webMatch.displayName)")
                detectedMeeting = webMatch
            }
            return
        }

        for meetingApp in MeetingApp.allCases where shouldMonitor(app: meetingApp, monitoredBundleIdentifiers: monitoredBundleIdentifiers) {
            if isMeetingActive(meetingApp, in: runningApps) {
                if self.detectedMeeting != meetingApp {
                    self.logger.info("Detected meeting: \(meetingApp.displayName)")
                    self.detectedMeeting = meetingApp
                }
                return
            }
        }

        if let monitoredAppBundleID = firstCustomMonitoredApp(in: runningApps, monitoredBundleIdentifiers: monitoredBundleIdentifiers) {
            if self.detectedMeeting != .unknown {
                self.logger.info("Detected meeting in monitored app: \(monitoredAppBundleID)")
                self.detectedMeeting = .unknown
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
            return WebTargetDetection.checkBrowserWindowTitles(for: app.windowTitlePatterns)
        }

        // For native apps, just check if running
        // More sophisticated detection could check window titles
        return true
    }

    private func shouldMonitor(app: MeetingApp, monitoredBundleIdentifiers: Set<String>) -> Bool {
        guard !app.bundleIdentifiers.isEmpty else { return false }
        return app.bundleIdentifiers.contains { monitoredBundleIdentifiers.contains(normalizeBundleIdentifier($0)) }
    }

    private func firstCustomMonitoredApp(
        in runningApps: [NSRunningApplication],
        monitoredBundleIdentifiers: Set<String>
    ) -> String? {
        for runningApp in runningApps {
            guard let bundleId = runningApp.bundleIdentifier else { continue }
            let normalizedBundleId = normalizeBundleIdentifier(bundleId)
            guard monitoredBundleIdentifiers.contains(normalizedBundleId) else { continue }
            if meetingApp(for: normalizedBundleId) == nil {
                return bundleId
            }
        }
        return nil
    }

    private func meetingApp(for normalizedBundleIdentifier: String) -> MeetingApp? {
        MeetingApp.allCases.first { app in
            app.bundleIdentifiers.contains { normalizeBundleIdentifier($0) == normalizedBundleIdentifier }
        }
    }

    private func normalizedMonitoredBundleIdentifiers() -> Set<String> {
        Set(settings.monitoredMeetingBundleIdentifiers.map(normalizeBundleIdentifier))
    }

    private func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func detectWebMeeting(
        in runningApps: [NSRunningApplication],
        monitoredBundleIdentifiers: Set<String>
    ) -> MeetingApp? {
        let targets = settings.webMeetingTargets
        guard !targets.isEmpty else { return nil }

        for runningApp in runningApps {
            guard let bundleId = runningApp.bundleIdentifier else { continue }
            let normalizedBundleId = normalizeBundleIdentifier(bundleId)
            guard monitoredBundleIdentifiers.contains(normalizedBundleId) else { continue }
            guard let provider = browserProviders[normalizedBundleId] else { continue }
            if let url = provider.activeTabURL() {
                if let match = WebTargetDetection.matchTarget(
                    for: url,
                    bundleIdentifier: normalizedBundleId,
                    targets: targets
                ) {
                    return match.app
                }
                continue
            }

            if let match = WebTargetDetection.matchTargetByWindowTitle(
                bundleIdentifier: normalizedBundleId,
                targets: targets,
                patternProvider: { target in
                    target.urlPatterns + target.app.windowTitlePatterns
                }
            ) {
                return match.app
            }
        }

        return nil
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
