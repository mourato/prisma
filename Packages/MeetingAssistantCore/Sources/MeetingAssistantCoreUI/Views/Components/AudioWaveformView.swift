import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

/// A simple bar-based waveform visualization.
public struct AudioWaveformView: View {
    let samples: [Float]
    let progress: Double
    let color: Color

    public init(samples: [Float], progress: Double, color: Color = .accentColor) {
        self.samples = samples
        self.progress = progress
        self.color = color
    }

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<samples.count, id: \.self) { index in
                    let sampleProgress = Double(index) / Double(samples.count)
                    let isActive = sampleProgress <= progress

                    RoundedRectangle(cornerRadius: 1)
                        .fill(isActive ? color : color.opacity(0.3))
                        .frame(height: geometry.size.height * CGFloat(samples[index]))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    AudioWaveformView(
        samples: [0.2, 0.4, 0.8, 0.5, 0.3, 0.9, 0.4, 0.2, 0.6, 0.8],
        progress: 0.5
    )
    .frame(width: 200, height: 40)
    .padding()
}
