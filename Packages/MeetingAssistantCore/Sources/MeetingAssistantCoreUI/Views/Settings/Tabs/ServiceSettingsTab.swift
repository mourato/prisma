import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Service Settings Tab

/// Tab for configuring local transcription service settings.
public struct ServiceSettingsTab: View {
    @MainActor
    public init() {}

    public var body: some View {
        ScrollView {
            ServiceSettingsContent()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ServiceSettingsTab()
}
