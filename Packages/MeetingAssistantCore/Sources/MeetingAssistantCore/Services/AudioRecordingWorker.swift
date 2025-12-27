import Atomics
@preconcurrency import AVFoundation
import Foundation
import os.log

// MARK: - Audio Recording Worker

/// A thread-safe, non-isolated worker class that handles Audio Processing and File Writing.
/// Extracted from AudioRecorder.swift to adhere to Single Responsibility Principle.
final class AudioRecordingWorker: @unchecked Sendable {
    // MARK: - State

    private var audioFile: AVAudioFile?
    private var currentURL: URL?

    // Thread safety
    private let queue = DispatchQueue(label: "MeetingAssistant.audioProcessing", qos: .userInitiated)
    private let lock = NSLock()

    // Atomic state for validation
    private let _hasReceivedValidBuffer = ManagedAtomic<Bool>(false)
    var hasReceivedValidBuffer: Bool {
        self._hasReceivedValidBuffer.load(ordering: .relaxed)
    }

    // Callbacks
    var onPowerUpdate: ((Float, Float) -> Void)?
    var onError: ((AudioRecorderError) -> Void)?

    init() {}

    // MARK: - Lifecycle

    func start(writingTo url: URL, format: AVAudioFormat) throws {
        self.lock.lock()
        defer { lock.unlock() }

        // Reset state
        self.audioFile = nil
        self._hasReceivedValidBuffer.store(false, ordering: .relaxed)

        // Prepare file
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        // Create AAC Settings
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 2, // Force Stereo
            AVEncoderBitRateKey: 128_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        // Create Audio File
        let file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        self.audioFile = file
        self.currentURL = url
    }

    func stop() async -> URL? {
        await withCheckedContinuation { continuation in
            self.queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                self.lock.lock()
                defer { self.lock.unlock() }

                let url = self.currentURL
                self.audioFile = nil // Close file
                self.currentURL = nil

                continuation.resume(returning: url)
            }
        }
    }

    // MARK: - Processing

    func process(_ buffer: AVAudioPCMBuffer) {
        self.queue.async { [weak self] in
            self?.processBufferInternal(buffer)
        }
    }

    private func processBufferInternal(_ buffer: AVAudioPCMBuffer) {
        self.calculateMeters(from: buffer)

        self.lock.lock()
        defer { lock.unlock() }

        guard let audioFile else { return }
        guard buffer.frameLength > 0 else { return }

        do {
            try audioFile.write(from: buffer)
            self._hasReceivedValidBuffer.store(true, ordering: .relaxed)
        } catch {
            self.onError?(AudioRecorderError.fileWriteFailed(error))
        }
    }

    private func calculateMeters(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return }

        let channel = channelData[0]
        var sum: Float = 0.0
        var peak: Float = 0.0

        // Downsample for metering (inspect every 10th sample)
        for frame in stride(from: 0, to: frameLength, by: 10) {
            let sample = channel[frame]
            let absSample = abs(sample)
            if absSample > peak { peak = absSample }
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength / 10)) // adjust count
        let averagePowerDb = 20.0 * log10(max(rms, 0.000_001))
        let peakPowerDb = 20.0 * log10(max(peak, 0.000_001))

        self.onPowerUpdate?(averagePowerDb, peakPowerDb)
    }
}
