import Foundation

/// Feature flags for MeetingAssistant application.
/// Toggle these values to enable/disable experimental or optional features.
public enum FeatureFlags {

    /// Enable XPC Service for transcription processing.
    /// When true: Uses MeetingAssistantAIClient (XPC) for heavy AI processing.
    /// When false: Uses LocalTranscriptionClient directly in the main app process.
    ///
    /// Benefits of XPC:
    /// - Process isolation (crashes don't affect main app)
    /// - Memory isolation (models don't bloat main app memory)
    /// - Sandboxed execution for security
    ///
    /// Drawbacks of XPC:
    /// - IPC overhead (serialization/deserialization)
    /// - More complex debugging
    /// - Additional build configuration
    public static let useXPCService: Bool = true

    /// Enable speaker diarization during transcription.
    /// Requires additional model downloads.
    public static let enableDiarization: Bool = true

    /// Enable AI post-processing for transcriptions.
    public static let enablePostProcessing: Bool = true

    /// Enable meeting auto-detection feature.
    public static let enableMeetingDetection: Bool = true

    /// Enable live waveform visualization during recording.
    public static let enableWaveformVisualization: Bool = false
}
