import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// Audio player component for transcriptions with waveform and playback controls.
public struct TranscriptionAudioPlayerView: View {
    private enum Layout {
        static let fixedWidth: CGFloat = 256
    }

    @StateObject private var viewModel = AudioPlayerViewModel()
    let audioURL: URL?

    public init(audioURL: URL?) {
        self.audioURL = audioURL
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(audioURL == nil)

            // Waveform and Progress Interaction
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Waveform
                    AudioWaveformView(
                        samples: viewModel.samples,
                        progress: viewModel.currentTime / max(viewModel.duration, 1),
                        color: .secondary
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                viewModel.seek(to: progress)
                            }
                    )
                }
            }
            .frame(height: AppDesignSystem.Layout.compactButtonHeight)

            // Duration
            Text(formatTime(viewModel.duration - viewModel.currentTime))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.cardCornerRadius))
        .frame(width: Layout.fixedWidth)
        .onAppear {
            if let url = audioURL {
                viewModel.loadAudio(url: url)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    TranscriptionAudioPlayerView(audioURL: nil)
        .padding()
        .frame(width: 400)
}
