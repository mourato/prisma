import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// Button component that opens a file picker for importing audio files to transcribe.
public struct TranscribeFileButton: View {
    @ObservedObject private var viewModel: RecordingViewModel

    public init(viewModel: RecordingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Button(action: selectAndTranscribeFile) {
            Label("transcribe.import_audio".localized, systemImage: "doc.badge.arrow.up")
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isTranscribing)
    }

    private func selectAndTranscribeFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .audio,
            .mpeg4Audio,
            .mp3,
            .wav,
        ]
        panel.message = "transcribe.import_audio.panel.message".localized
        panel.prompt = "transcribe.import_audio.panel.prompt".localized

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.transcribeFile(at: url)
            }
        }
    }
}

#Preview {
    TranscribeFileButton(viewModel: RecordingViewModel(recordingManager: RecordingManager.shared))
}
