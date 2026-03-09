import Foundation
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreInfrastructure
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class CalendarEventFilteringAndIgnoreTests: XCTestCase {
    private var settings: AppSettingsStore!
    private var originalIgnoredIdentifiers: Set<String> = []

    override func setUp() async throws {
        try await super.setUp()
        settings = AppSettingsStore.shared
        originalIgnoredIdentifiers = settings.ignoredCalendarEventIdentifiers()
    }

    override func tearDown() async throws {
        restoreIgnoredIdentifiers()
        settings = nil
        try await super.tearDown()
    }

    func testUpcomingEventEligibilityFiltersSoloEventsWithoutCallLinks() {
        XCTAssertFalse(
            CalendarEventService.isEligibleUpcomingEvent(
                attendeeCount: 1,
                searchableValues: []
            )
        )

        XCTAssertTrue(
            CalendarEventService.isEligibleUpcomingEvent(
                attendeeCount: 1,
                searchableValues: ["https://meet.google.com/abc-defg-hij"]
            )
        )

        XCTAssertTrue(
            CalendarEventService.isEligibleUpcomingEvent(
                attendeeCount: 3,
                searchableValues: []
            )
        )
    }

    func testIgnoredEventIdentifiersPersistAndRoundTrip() {
        settings.ignoreCalendarEventIdentifier("event-a")
        settings.ignoreCalendarEventIdentifier("event-b")

        var ignored = settings.ignoredCalendarEventIdentifiers()
        XCTAssertTrue(ignored.contains("event-a"))
        XCTAssertTrue(ignored.contains("event-b"))

        settings.unignoreCalendarEventIdentifier("event-a")

        ignored = settings.ignoredCalendarEventIdentifiers()
        XCTAssertFalse(ignored.contains("event-a"))
        XCTAssertTrue(ignored.contains("event-b"))
    }

    func testDashboardRefreshPassesIgnoredIdentifiersToCalendarService() async {
        let ignoredIdentifier = "calendar-event-ignored"
        settings.ignoreCalendarEventIdentifier(ignoredIdentifier)

        let calendarService = MockCalendarEventService()
        calendarService.eventsToReturn = [
            MeetingCalendarEventSnapshot(
                eventIdentifier: ignoredIdentifier,
                title: "Lunch break",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3_600),
                attendees: []
            ),
            MeetingCalendarEventSnapshot(
                eventIdentifier: "calendar-event-team-sync",
                title: "Team Sync",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3_600),
                attendees: ["Alice", "Bob"]
            ),
        ]

        let viewModel = MetricsDashboardViewModel(
            storage: MockStorageService(),
            calendarEventService: calendarService,
            recordingManager: .shared,
            settingsStore: settings
        )

        await viewModel.load()

        XCTAssertEqual(calendarService.lastIgnoredIdentifiers, [ignoredIdentifier])
        XCTAssertEqual(viewModel.upcomingEvents.map(\.eventIdentifier), ["calendar-event-team-sync"])
    }

    private func restoreIgnoredIdentifiers() {
        let current = settings.ignoredCalendarEventIdentifiers()

        for identifier in current.subtracting(originalIgnoredIdentifiers) {
            settings.unignoreCalendarEventIdentifier(identifier)
        }

        for identifier in originalIgnoredIdentifiers.subtracting(current) {
            settings.ignoreCalendarEventIdentifier(identifier)
        }
    }
}

@MainActor
private final class MockCalendarEventService: CalendarEventServiceProtocol, @unchecked Sendable {
    var eventsToReturn: [MeetingCalendarEventSnapshot] = []
    var lastIgnoredIdentifiers: Set<String> = []

    func authorizationState() -> PermissionState {
        .granted
    }

    func requestAccess() async -> PermissionState {
        .granted
    }

    func openSystemSettings() {}

    func fetchUpcomingEvents(
        limit _: Int,
        now _: Date,
        window _: TimeInterval,
        ignoredEventIdentifiers: Set<String>
    ) throws -> [MeetingCalendarEventSnapshot] {
        lastIgnoredIdentifiers = ignoredEventIdentifiers
        return eventsToReturn.filter { !ignoredEventIdentifiers.contains($0.eventIdentifier) }
    }

    func bestMatchingEvent(
        at _: Date,
        in events: [MeetingCalendarEventSnapshot]
    ) -> MeetingCalendarEventSnapshot? {
        events.first
    }
}
