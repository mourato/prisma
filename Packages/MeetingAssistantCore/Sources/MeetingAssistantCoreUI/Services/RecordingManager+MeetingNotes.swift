import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain

extension RecordingManager {
    private enum MeetingNotesConstants {
        static let userDefaultsKeyPrefix = "meetingNotes."
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
        guard currentCapturePurpose == .meeting,
              let meetingID = currentMeeting?.id
        else {
            currentMeetingNotesText = ""
            return
        }

        currentMeetingNotesText = text
        saveMeetingNotesText(text, for: meetingID)
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
        UserDefaults.standard.set(text, forKey: meetingNotesKey(for: meetingID))
    }

    private func removeMeetingNotesText(for meetingID: UUID) {
        UserDefaults.standard.removeObject(forKey: meetingNotesKey(for: meetingID))
    }

    private func meetingNotesKey(for meetingID: UUID) -> String {
        MeetingNotesConstants.userDefaultsKeyPrefix + meetingID.uuidString
    }
}
