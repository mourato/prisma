import MeetingAssistantCoreAudio
import SwiftUI

#Preview("Classic", traits: .sizeThatFitsLayout) {
    let monitor = AudioLevelMonitor()
    FloatingRecordingIndicatorView(
        audioMonitor: monitor,
        style: .classic,
        renderState: RecordingIndicatorRenderState(mode: .recording, kind: .dictation),
        previewLanguageOverride: .portuguese,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 520, height: 120)
    .background(AppDesignSystem.Colors.neutral.opacity(0.8))
}
