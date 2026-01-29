import Combine
import Foundation

/// Monitors audio levels from RecordingManager and publishes normalized samples for waveform visualization.
/// Samples are normalized to the 0...1 range required by WaveformLiveCanvas.
@MainActor
public final class AudioLevelMonitor: ObservableObject {
    // MARK: - Published Properties

    /// Array of normalized samples (0...1) for waveform rendering.
    /// Newer samples are appended to the end.
    @Published public private(set) var samples: [Float] = []

    // MARK: - Configuration

    /// Maximum number of samples to maintain in the buffer.
    private let maxSamples: Int

    /// Interval for sampling audio levels.
    private let samplingInterval: TimeInterval

    // MARK: - Private State

    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private weak var audioRecorder: AudioRecorder?

    // MARK: - Initialization

    /// Creates a new audio level monitor.
    /// - Parameters:
    ///   - audioRecorder: The AudioRecorder instance to monitor.
    ///   - maxSamples: Maximum number of samples to keep (determines waveform width). Default: 50.
    ///   - samplingInterval: How often to sample audio levels. Default: 0.05s (20Hz).
    public init(
        audioRecorder: AudioRecorder = .shared,
        maxSamples: Int = 50,
        samplingInterval: TimeInterval = 0.05
    ) {
        self.audioRecorder = audioRecorder
        self.maxSamples = maxSamples
        self.samplingInterval = samplingInterval
    }

    // MARK: - Public API

    /// Start monitoring audio levels.
    /// Called when recording starts.
    public func startMonitoring() {
        samples = []

        timer = Timer.publish(every: samplingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.sampleCurrentLevel()
            }
    }

    /// Stop monitoring audio levels.
    /// Called when recording stops.
    public func stopMonitoring() {
        timer?.cancel()
        timer = nil
        samples = []
    }

    // MARK: - Private Helpers

    private func sampleCurrentLevel() {
        guard let recorder = audioRecorder else { return }

        // Get current average power from AudioRecorder
        // Power is typically in dB range from -160 (silence) to 0 (max)
        let powerDB = recorder.currentAveragePower

        // Normalize from dB to 0...1 range
        // Using a reference range of -60dB (quiet) to 0dB (loud)
        let normalized = normalizeDecibels(powerDB, minDB: -60, maxDB: 0)

        // Add sample and trim if needed
        samples.append(normalized)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    /// Normalizes a decibel value to the 0...1 range.
    /// - Parameters:
    ///   - db: The decibel value to normalize.
    ///   - minDB: The minimum dB value (maps to 0).
    ///   - maxDB: The maximum dB value (maps to 1).
    /// - Returns: A normalized value between 0 and 1.
    private func normalizeDecibels(_ db: Float, minDB: Float, maxDB: Float) -> Float {
        // Clamp to valid range
        let clampedDB = max(minDB, min(maxDB, db))
        // Linear interpolation from minDB...maxDB to 0...1
        let normalized = (clampedDB - minDB) / (maxDB - minDB)
        return normalized
    }
}
