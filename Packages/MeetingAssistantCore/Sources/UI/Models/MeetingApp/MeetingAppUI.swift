import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public extension MeetingApp {
    var color: Color {
        switch self {
        case .googleMeet: .green
        case .microsoftTeams: .purple
        case .discord: .indigo
        case .slack: .pink
        case .whatsApp: .green
        case .zoom: .blue
        case .manualMeeting: .teal
        case .importedFile: .orange
        case .unknown: .gray
        }
    }
}

public extension Meeting {
    var appColor: Color {
        app.color
    }
}
