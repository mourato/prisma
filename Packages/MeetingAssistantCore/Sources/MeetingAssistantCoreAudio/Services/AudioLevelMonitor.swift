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
    /// Elapsed monitoring time for the current recording session.
    private var monitoringElapsed: TimeInterval = 0
    /// Tracks whether the warning has already been presented in the current session.
    private var didPresentSilenceWarningThisSession = false

    private enum Constants {
        static let silenceThresholdDb: Float = -50
        static let silenceDurationSeconds: TimeInterval = 4
        static let silenceWarningStartupWindowSeconds: TimeInterval = 10
        static let timerToleranceRatio: Double = 0.05
        static let levelAttackSmoothingFactor: Double = 0.80
        static let levelReleaseSmoothingFactor: Double = 0.90
        static let meterMinDb: Float = -50
        static let meterMaxDb: Float = -6
    }

    // MARK: - Private State

    private var timer: AnyCancellable?
    private weak var audioRecorder: AudioRecorder?
    private var smoothedAveragePower: Double = 0
    private var smoothedPeakPower: Double = 0

    // MARK: - Initialization

    /// Creates a new audio level monitor.
    /// - Parameters:
    ///   - audioRecorder: The AudioRecorder instance to monitor.
    ///   - samplingInterval: How often to sample audio levels. Default: 0.03s (~33Hz).
    public init(
        audioRecorder: AudioRecorder = .shared,
        samplingInterval: TimeInterval = 0.03
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
        monitoringElapsed = 0
        didPresentSilenceWarningThisSession = false
        smoothedAveragePower = 0
        smoothedPeakPower = 0

        timer = Timer.publish(
            every: samplingInterval,
            tolerance: samplingInterval * Constants.timerToleranceRatio,
            on: .main,
            in: .common
        )
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
        monitoringElapsed = 0
        didPresentSilenceWarningThisSession = false
        smoothedAveragePower = 0
        smoothedPeakPower = 0
    }

    /// Dismiss the silence warning until silence is detected again.
    public func dismissSilenceWarning() {
        isSilenceWarningVisible = false
        silenceElapsed = 0
        didPresentSilenceWarningThisSession = true
    }

    // MARK: - Private Helpers

    private func sampleCurrentLevel() {
        guard let recorder = audioRecorder else { return }

        // Get current average and peak power from AudioRecorder
        ingestLevels(averageDB: recorder.currentAveragePower, peakDB: recorder.currentPeakPower)
    }

    /// Ingests a pair of dB levels and updates published meter/warning state.
    /// Exposed as internal for deterministic unit testing without audio hardware.
    func ingestLevels(averageDB: Float, peakDB: Float) {

        updateSilenceWarning(with: averageDB)

        // Normalize from dB to 0...1 range.
        // Apply the configured silence threshold as a hard cutoff so that
        // any dB value at-or-below `silenceThresholdDb` maps to 0 (no bar movement).
        let normalizedAverage: Float
        let normalizedPeak: Float

        if averageDB <= Constants.silenceThresholdDb {
            normalizedAverage = 0.0
        } else {
            normalizedAverage = normalizeDecibels(
                averageDB,
                minDB: Constants.meterMinDb,
                maxDB: Constants.meterMaxDb
            )
        }

        if peakDB <= Constants.silenceThresholdDb {
            normalizedPeak = 0.0
        } else {
            normalizedPeak = normalizeDecibels(
                peakDB,
                minDB: Constants.meterMinDb,
                maxDB: Constants.meterMaxDb
            )
        }

        smoothedAveragePower = applyAsymmetricSmoothing(
            current: smoothedAveragePower,
            target: Double(normalizedAverage)
        )
        smoothedPeakPower = applyAsymmetricSmoothing(
            current: smoothedPeakPower,
            target: Double(normalizedPeak)
        )

        audioMeter = AudioMeter(
            averagePower: smoothedAveragePower,
            peakPower: smoothedPeakPower
        )
    }

    private func updateSilenceWarning(with averageDB: Float) {
        monitoringElapsed += samplingInterval

        if didPresentSilenceWarningThisSession {
            if averageDB > Constants.silenceThresholdDb, isSilenceWarningVisible {
                isSilenceWarningVisible = false
            }
            silenceElapsed = 0
            return
        }

        guard monitoringElapsed <= Constants.silenceWarningStartupWindowSeconds else {
            silenceElapsed = 0
            if isSilenceWarningVisible {
                isSilenceWarningVisible = false
            }
            return
        }

        if averageDB <= Constants.silenceThresholdDb {
            silenceElapsed += samplingInterval
            if silenceElapsed >= Constants.silenceDurationSeconds, !isSilenceWarningVisible {
                isSilenceWarningVisible = true
                didPresentSilenceWarningThisSession = true
            }
        } else {
            silenceElapsed = 0
            if isSilenceWarningVisible {
                isSilenceWarningVisible = false
            }
        }
    }

    private func applyAsymmetricSmoothing(current: Double, target: Double) -> Double {
        let alpha = target > current
            ? Constants.levelAttackSmoothingFactor
            : Constants.levelReleaseSmoothingFactor
        return current + alpha * (target - current)
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
