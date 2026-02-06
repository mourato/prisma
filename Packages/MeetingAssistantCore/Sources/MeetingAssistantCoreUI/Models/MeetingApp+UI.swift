import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public extension MeetingApp {
    var color: Color {
        switch self {
        case .googleMeet: .green
        case .microsoftTeams: .purple
        case .slack: .pink
        case .zoom: .blue
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
