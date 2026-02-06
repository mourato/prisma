import Combine
import Foundation

/// Represents audio levels for visualization.
public struct AudioMeter: Equatable, Sendable {
    public let averagePower: Double
    public let peakPower: Double

    public init(averagePower: Double, peakPower: Double) {
        self.averagePower = averagePower
        self.peakPower = peakPower
    }

    public static let zero = AudioMeter(averagePower: 0, peakPower: 0)
}

/// Monitors audio levels from RecordingManager and publishes normalized samples for waveform visualization.
@MainActor
public final class AudioLevelMonitor: ObservableObject {
    // MARK: - Published Properties

    /// Current audio meter levels (0...1 normalized).
    @Published public private(set) var audioMeter: AudioMeter = .zero
    /// Whether the monitor detected prolonged silence from the microphone.
    @Published public private(set) var isSilenceWarningVisible = false

    // MARK: - Configuration

    /// Interval for sampling audio levels.
    private let samplingInterval: TimeInterval
    /// Accumulated time spent below the silence threshold.
    private var silenceElapsed: TimeInterval = 0

    private enum Constants {
        static let silenceThresholdDb: Float = -80
        static let silenceDurationSeconds: TimeInterval = 4
    }

    // MARK: - Private State

    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private weak var audioRecorder: AudioRecorder?

    // MARK: - Initialization

    /// Creates a new audio level monitor.
    /// - Parameters:
    ///   - audioRecorder: The AudioRecorder instance to monitor.
    ///   - samplingInterval: How often to sample audio levels. Default: 0.05s (20Hz).
    public init(
        audioRecorder: AudioRecorder = .shared,
        samplingInterval: TimeInterval = 0.05
    ) {
        self.audioRecorder = audioRecorder
        self.samplingInterval = samplingInterval
    }

    // MARK: - Public API

    /// Start monitoring audio levels.
    /// Called when recording starts.
    public func startMonitoring() {
        audioMeter = .zero
        isSilenceWarningVisible = false
        silenceElapsed = 0

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
        audioMeter = .zero
        isSilenceWarningVisible = false
        silenceElapsed = 0
    }

    /// Dismiss the silence warning until silence is detected again.
    public func dismissSilenceWarning() {
        isSilenceWarningVisible = false
        silenceElapsed = 0
    }

    // MARK: - Private Helpers

    private func sampleCurrentLevel() {
        guard let recorder = audioRecorder else { return }

        // Get current average and peak power from AudioRecorder
        let averageDB = recorder.currentAveragePower
        let peakDB = recorder.currentPeakPower

        updateSilenceWarning(with: averageDB)

        // Normalize from dB to 0...1 range
        let normalizedAverage = normalizeDecibels(averageDB, minDB: -60, maxDB: 0)
        let normalizedPeak = normalizeDecibels(peakDB, minDB: -60, maxDB: 0)

        audioMeter = AudioMeter(
            averagePower: Double(normalizedAverage),
            peakPower: Double(normalizedPeak)
        )
    }

    private func updateSilenceWarning(with averageDB: Float) {
        if averageDB <= Constants.silenceThresholdDb {
            silenceElapsed += samplingInterval
            if silenceElapsed >= Constants.silenceDurationSeconds {
                isSilenceWarningVisible = true
            }
        } else {
            silenceElapsed = 0
            isSilenceWarningVisible = false
        }
    }

    /// Normalizes a decibel value to the 0...1 range.
    private func normalizeDecibels(_ db: Float, minDB: Float, maxDB: Float) -> Float {
        if db < minDB {
            0.0
        } else if db >= maxDB {
            1.0
        } else {
            (db - minDB) / (maxDB - minDB)
        }
    }
}
