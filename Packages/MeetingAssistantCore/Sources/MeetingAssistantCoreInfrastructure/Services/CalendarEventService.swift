import AppKit
import EventKit
import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

@MainActor
public protocol CalendarEventServiceProtocol: Sendable {
    func authorizationState() -> PermissionState
    func requestAccess() async -> PermissionState
    func openSystemSettings()
    func fetchUpcomingEvents(
        limit: Int,
        now: Date,
        window: TimeInterval
    ) throws -> [MeetingCalendarEventSnapshot]
    func bestMatchingEvent(
        at startDate: Date,
        in events: [MeetingCalendarEventSnapshot]
    ) -> MeetingCalendarEventSnapshot?
}

@MainActor
public final class CalendarEventService: CalendarEventServiceProtocol {
    public static let shared = CalendarEventService()

    private enum Constants {
        static let autoLinkLeadWindow: TimeInterval = 30 * 60
        static let calendarPrivacyURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
    }

    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func authorizationState() -> PermissionState {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted, .writeOnly:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    public func requestAccess() async -> PermissionState {
        do {
            if #available(macOS 14.0, *) {
                _ = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestFullAccessToEvents { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                } as Bool
            } else {
                _ = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                } as Bool
            }
        } catch {
            AppLogger.error("Calendar access request failed", category: .recordingManager, error: error)
        }

        return authorizationState()
    }

    public func openSystemSettings() {
        guard let url = URL(string: Constants.calendarPrivacyURL) else { return }
        NSWorkspace.shared.open(url)
    }

    public func fetchUpcomingEvents(
        limit: Int = 10,
        now: Date = Date(),
        window: TimeInterval = 24 * 60 * 60
    ) throws -> [MeetingCalendarEventSnapshot] {
        guard authorizationState().isAuthorized else { return [] }

        let endDate = now.addingTimeInterval(window)
        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)

        return eventStore.events(matching: predicate)
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
            .prefix(limit)
            .map(snapshot(from:))
    }

    public func bestMatchingEvent(
        at startDate: Date,
        in events: [MeetingCalendarEventSnapshot]
    ) -> MeetingCalendarEventSnapshot? {
        if let ongoing = events.first(where: { $0.startDate <= startDate && $0.endDate >= startDate }) {
            return ongoing
        }

        return events
            .filter {
                $0.startDate > startDate &&
                    $0.startDate.timeIntervalSince(startDate) <= Constants.autoLinkLeadWindow
            }
            .min(by: { $0.startDate < $1.startDate })
    }

    private func snapshot(from event: EKEvent) -> MeetingCalendarEventSnapshot {
        MeetingCalendarEventSnapshot(
            eventIdentifier: event.eventIdentifier,
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location?.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            attendees: attendeeDisplayValues(from: event.attendees)
        )
    }

    private func attendeeDisplayValues(from attendees: [EKParticipant]?) -> [String] {
        (attendees ?? [])
            .compactMap { participant in
                let trimmedName = participant.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let trimmedName, !trimmedName.isEmpty {
                    return trimmedName
                }

                let fallbackEmail = participant.url.absoluteString
                    .replacingOccurrences(of: "mailto:", with: "")
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                return fallbackEmail.isEmpty ? nil : fallbackEmail
            }
    }
}
