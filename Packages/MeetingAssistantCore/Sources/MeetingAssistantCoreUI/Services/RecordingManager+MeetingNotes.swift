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
        let content = loadMeetingNotesContent(for: meetingID)
        currentMeetingNotesText = content.plainText
        currentMeetingNotesRichTextData = content.richTextRTFData
    }

    public func updateMeetingNotes(_ content: MeetingNotesContent) {
        guard let meeting = currentMeeting,
              meeting.capturePurpose == .meeting
        else {
            currentMeetingNotesText = ""
            currentMeetingNotesRichTextData = nil
            return
        }

        currentMeetingNotesText = content.plainText
        currentMeetingNotesRichTextData = content.richTextRTFData
        saveMeetingNotesContent(content, for: meeting.id)

        if let linkedEventIdentifier = meeting.linkedCalendarEvent?.eventIdentifier {
            saveCalendarEventNotesContent(content, for: linkedEventIdentifier)
        }
    }

    public func updateMeetingNotesText(_ text: String) {
        updateMeetingNotes(MeetingNotesContent(plainText: text))
    }

    func loadCalendarEventNotesContent(for eventIdentifier: String) -> MeetingNotesContent {
        guard let normalizedIdentifier = normalizedCalendarEventIdentifier(eventIdentifier) else {
            return .empty
        }

        let plainText = UserDefaults.standard.string(forKey: calendarEventNotesKey(for: normalizedIdentifier)) ?? ""
        let richTextRTFData = meetingNotesRichTextStore.calendarEventNotesRTFData(for: normalizedIdentifier)
        return MeetingNotesContent(plainText: plainText, richTextRTFData: richTextRTFData)
    }

    func loadCalendarEventNotesText(for eventIdentifier: String) -> String {
        loadCalendarEventNotesContent(for: eventIdentifier).plainText
    }

    func updateCalendarEventNotes(_ content: MeetingNotesContent, for eventIdentifier: String) {
        guard let normalizedIdentifier = normalizedCalendarEventIdentifier(eventIdentifier) else {
            return
        }

        saveCalendarEventNotesContent(content, for: normalizedIdentifier)

        guard let meeting = currentMeeting,
              meeting.capturePurpose == .meeting,
              meeting.linkedCalendarEvent?.eventIdentifier == normalizedIdentifier
        else {
            return
        }

        currentMeetingNotesText = content.plainText
        currentMeetingNotesRichTextData = content.richTextRTFData
        saveMeetingNotesContent(content, for: meeting.id)
    }

    func updateCalendarEventNotesText(_ text: String, for eventIdentifier: String) {
        updateCalendarEventNotes(MeetingNotesContent(plainText: text), for: eventIdentifier)
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

        let eventNotes = loadCalendarEventNotesContent(for: normalizedIdentifier).plainText
        let mergedNotes = mergeLinkedNotes(eventNotes: eventNotes, meetingNotes: currentMeetingNotesText)

        currentMeetingNotesText = mergedNotes
        currentMeetingNotesRichTextData = nil

        // Merge currently operates on plain text, so rich formatting is intentionally reset.
        let mergedContent = MeetingNotesContent(plainText: mergedNotes, richTextRTFData: nil)
        saveMeetingNotesContent(mergedContent, for: meeting.id)
        saveCalendarEventNotesContent(mergedContent, for: normalizedIdentifier)
    }

    func currentMeetingNotesContextItem() -> TranscriptionContextItem? {
        guard currentCapturePurpose == .meeting else { return nil }

        let trimmed = currentMeetingNotesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return TranscriptionContextItem(source: .meetingNotes, text: trimmed)
    }

    func clearMeetingNotesState(removePersistedValue: Bool) {
        if removePersistedValue, let meetingID = currentMeeting?.id {
            removeMeetingNotesContent(for: meetingID)
        }

        isMeetingNotesPanelVisible = false
        currentMeetingNotesText = ""
        currentMeetingNotesRichTextData = nil
    }

    func loadMeetingNotesContent(for meetingID: UUID) -> MeetingNotesContent {
        let plainText = UserDefaults.standard.string(forKey: meetingNotesKey(for: meetingID)) ?? ""
        let richTextRTFData = meetingNotesRichTextStore.meetingNotesRTFData(for: meetingID)
        return MeetingNotesContent(plainText: plainText, richTextRTFData: richTextRTFData)
    }

    private func saveMeetingNotesContent(_ content: MeetingNotesContent, for meetingID: UUID) {
        if normalizedNotesValue(content.plainText).isEmpty {
            UserDefaults.standard.removeObject(forKey: meetingNotesKey(for: meetingID))
            meetingNotesRichTextStore.saveMeetingNotesRTFData(nil, for: meetingID)
            return
        }

        UserDefaults.standard.set(content.plainText, forKey: meetingNotesKey(for: meetingID))
        meetingNotesRichTextStore.saveMeetingNotesRTFData(content.richTextRTFData, for: meetingID)
    }

    private func removeMeetingNotesContent(for meetingID: UUID) {
        UserDefaults.standard.removeObject(forKey: meetingNotesKey(for: meetingID))
        meetingNotesRichTextStore.saveMeetingNotesRTFData(nil, for: meetingID)
    }

    private func meetingNotesKey(for meetingID: UUID) -> String {
        MeetingNotesConstants.userDefaultsKeyPrefix + meetingID.uuidString
    }

    private func saveCalendarEventNotesContent(_ content: MeetingNotesContent, for eventIdentifier: String) {
        guard let normalizedIdentifier = normalizedCalendarEventIdentifier(eventIdentifier) else { return }
        let key = calendarEventNotesKey(for: normalizedIdentifier)
        if normalizedNotesValue(content.plainText).isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            meetingNotesRichTextStore.saveCalendarEventNotesRTFData(nil, for: normalizedIdentifier)
            return
        }

        UserDefaults.standard.set(content.plainText, forKey: key)
        meetingNotesRichTextStore.saveCalendarEventNotesRTFData(content.richTextRTFData, for: normalizedIdentifier)
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
