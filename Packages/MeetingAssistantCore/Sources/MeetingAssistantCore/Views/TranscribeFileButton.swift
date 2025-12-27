import SwiftUI

/// Button component that opens a file picker for importing audio files to transcribe.
public struct TranscribeFileButton: View {
    @ObservedObject private var viewModel: RecordingViewModel

    public init(viewModel: RecordingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Button(action: self.selectAndTranscribeFile) {
            Label(NSLocalizedString("transcribe.import_audio", bundle: .safeModule, comment: ""), systemImage: "doc.badge.arrow.up")
        }
        .buttonStyle(.bordered)
        .disabled(self.viewModel.isTranscribing)
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
        panel.message = "Selecione um arquivo de áudio para transcrever"
        panel.prompt = "Transcrever"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await self.viewModel.transcribeFile(at: url)
            }
        }
    }
}

#Preview {
    TranscribeFileButton(viewModel: RecordingViewModel())
}
