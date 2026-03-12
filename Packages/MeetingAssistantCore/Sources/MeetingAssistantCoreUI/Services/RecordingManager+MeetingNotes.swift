import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

extension RecordingManager {
    private enum MeetingNotesConstants {
        static let userDefaultsKeyPrefix = "meetingNotes."
        static let eventUserDefaultsKeyPrefix = "meetingNotes.event."
        static let mergeSeparator = "\n\n---\n\n"
    }

    public func toggleMeetingNotesPanel() {
        guard currentCapturePurpose == .meeting else { return }
        isMeetingNotesPanelVisible.toggle()
    }

    public func setMeetingNotesPanelVisible(_ isVisible: Bool) {
        guard currentCapturePurpose == .meeting else {
            isMeetingNotesPanelVisible = false
            return
        }
        isMeetingNotesPanelVisible = isVisible
    }

    func restoreMeetingNotesIfNeeded(for meetingID: UUID) {
        currentMeetingNotesText = loadMeetingNotesText(for: meetingID)
    }

    public func updateMeetingNotesText(_ text: String) {
        guard let meeting = currentMeeting,
              meeting.capturePurpose == .meeting
        else {
            currentMeetingNotesText = ""
            return
        }

        currentMeetingNotesText = text
        saveMeetingNotesText(text, for: meeting.id)

        if let linkedEventIdentifier = meeting.linkedCalendarEvent?.eventIdentifier {
            saveCalendarEventNotesText(text, for: linkedEventIdentifier)
        }
    }

    func loadCalendarEventNotesText(for eventIdentifier: String) -> String {
        guard let normalizedIdentifier = normalizedCalendarEventIdentifier(eventIdentifier) else {
            return ""
        }
        return UserDefaults.standard.string(forKey: calendarEventNotesKey(for: normalizedIdentifier)) ?? ""
    }

    func updateCalendarEventNotesText(_ text: String, for eventIdentifier: String) {
        guard let normalizedIdentifier = normalizedCalendarEventIdentifier(eventIdentifier) else {
            return
        }

        saveCalendarEventNotesText(text, for: normalizedIdentifier)

        guard let meeting = currentMeeting,
              meeting.capturePurpose == .meeting,
              meeting.linkedCalendarEvent?.eventIdentifier == normalizedIdentifier
        else {
            return
        }

        currentMeetingNotesText = text
        saveMeetingNotesText(text, for: meeting.id)
    }

    func synchronizeMeetingNotesWithLinkedCalendarEventIfNeeded(
        linkedEventIdentifier overrideLinkedEventIdentifier: String? = nil
    ) {
        guard let meeting = currentMeeting,
              meeting.capturePurpose == .meeting
        else {
            return
        }

        let linkedEventIdentifier = overrideLinkedEventIdentifier ?? meeting.linkedCalendarEvent?.eventIdentifier
        guard let linkedEventIdentifier,
              let normalizedIdentifier = normalizedCalendarEventIdentifier(linkedEventIdentifier)
        else {
            return
        }

        let eventNotes = loadCalendarEventNotesText(for: normalizedIdentifier)
        let mergedNotes = mergeLinkedNotes(eventNotes: eventNotes, meetingNotes: currentMeetingNotesText)

        currentMeetingNotesText = mergedNotes
        saveMeetingNotesText(mergedNotes, for: meeting.id)
        saveCalendarEventNotesText(mergedNotes, for: normalizedIdentifier)
    }

    func currentMeetingNotesContextItem() -> TranscriptionContextItem? {
        guard currentCapturePurpose == .meeting else { return nil }

        let trimmed = currentMeetingNotesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return TranscriptionContextItem(source: .meetingNotes, text: trimmed)
    }

    func clearMeetingNotesState(removePersistedValue: Bool) {
        if removePersistedValue, let meetingID = currentMeeting?.id {
            removeMeetingNotesText(for: meetingID)
        }

        isMeetingNotesPanelVisible = false
        currentMeetingNotesText = ""
    }

    private func loadMeetingNotesText(for meetingID: UUID) -> String {
        UserDefaults.standard.string(forKey: meetingNotesKey(for: meetingID)) ?? ""
    }

    private func saveMeetingNotesText(_ text: String, for meetingID: UUID) {
        if normalizedNotesValue(text).isEmpty {
            UserDefaults.standard.removeObject(forKey: meetingNotesKey(for: meetingID))
            return
        }

        UserDefaults.standard.set(text, forKey: meetingNotesKey(for: meetingID))
    }

    private func removeMeetingNotesText(for meetingID: UUID) {
        UserDefaults.standard.removeObject(forKey: meetingNotesKey(for: meetingID))
    }

    private func meetingNotesKey(for meetingID: UUID) -> String {
        MeetingNotesConstants.userDefaultsKeyPrefix + meetingID.uuidString
    }

    private func saveCalendarEventNotesText(_ text: String, for eventIdentifier: String) {
        guard let normalizedIdentifier = normalizedCalendarEventIdentifier(eventIdentifier) else { return }
        let key = calendarEventNotesKey(for: normalizedIdentifier)
        if normalizedNotesValue(text).isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        UserDefaults.standard.set(text, forKey: key)
    }

    private func calendarEventNotesKey(for eventIdentifier: String) -> String {
        MeetingNotesConstants.eventUserDefaultsKeyPrefix + eventIdentifier
    }

    private func normalizedCalendarEventIdentifier(_ identifier: String) -> String? {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedNotesValue(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mergeLinkedNotes(eventNotes: String, meetingNotes: String) -> String {
        let normalizedEventNotes = normalizedNotesValue(eventNotes)
        let normalizedMeetingNotes = normalizedNotesValue(meetingNotes)

        if normalizedEventNotes.isEmpty {
            return meetingNotes
        }

        if normalizedMeetingNotes.isEmpty {
            return eventNotes
        }

        if normalizedEventNotes == normalizedMeetingNotes {
            return eventNotes
        }

        return normalizedEventNotes
            + MeetingNotesConstants.mergeSeparator
            + normalizedMeetingNotes
    }
}
