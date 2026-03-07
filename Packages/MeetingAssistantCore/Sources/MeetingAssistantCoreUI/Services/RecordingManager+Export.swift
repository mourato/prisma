import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Summary Export

extension RecordingManager {
    /// Export summary to configured folder with safety checks.
    func exportSummary(transcription: Transcription) async {
        let helper = SummaryExportHelper()
        await helper.exportAutomatically(transcription: transcription)
    }
}
