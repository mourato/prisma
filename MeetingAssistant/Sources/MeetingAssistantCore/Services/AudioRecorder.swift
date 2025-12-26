import Foundation
@preconcurrency import AVFoundation
import CoreAudio
import AppKit
import os.log

// MARK: - Audio Recorder (Microphone Only)

/// VoiceInk-style audio recorder using AVAudioEngine with direct file writing.
/// Records microphone audio to a 16kHz Mono WAV file.
@MainActor
public class AudioRecorder: ObservableObject {
    public static let shared = AudioRecorder()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "AudioRecorder")
    
    @Published public private(set) var isRecording = false
    @Published public private(set) var currentRecordingURL: URL?
    @Published public private(set) var error: Error?
    @Published public private(set) var currentAveragePower: Float = -160.0
    @Published public private(set) var currentPeakPower: Float = -160.0
    
    // MARK: - Audio Engine
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // Thread-safe file handling (nonisolated for use in tap callback)
    nonisolated(unsafe) private var audioFile: AVAudioFile?
    nonisolated(unsafe) private var recordingFormat: AVAudioFormat?
    nonisolated(unsafe) private var converter: AVAudioConverter?
    
    // MARK: - Configuration
    private let tapBufferSize: AVAudioFrameCount = 4096
    private let tapBusNumber: AVAudioNodeBus = 0
    
    // Output format: 16kHz Mono (optimized for transcription)
    private let outputSampleRate: Double = 16000.0
    private let outputChannels: AVAudioChannelCount = 1
    
    // MARK: - Thread Safety
    private let audioProcessingQueue = DispatchQueue(
        label: "MeetingAssistant.audioProcessing",
        qos: .userInitiated
    )
    private let fileWriteLock = NSLock()
    
    // MARK: - Validation & Retry
    private var validationTimer: Timer?
    nonisolated(unsafe) private var hasReceivedValidBuffer = false
    public var onRecordingError: ((Error) -> Void)?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Start recording microphone audio to the specified URL.
    /// Uses automatic retry mechanism if initial start fails.
    public func startRecording(to outputURL: URL, retryCount: Int = 0) throws {
        // Stop any existing recording first
        stopRecording()
        hasReceivedValidBuffer = false
        
        logger.info("Starting microphone recording to: \(outputURL.path)")
        
        // Create new engine instance
        let engine = AVAudioEngine()
        audioEngine = engine
        
        let input = engine.inputNode
        inputNode = input
        
        // Get the input format from hardware
        let inputFormat = input.outputFormat(forBus: tapBusNumber)
        
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            logger.error("Invalid input format: sample rate or channel count is zero")
            throw AudioRecorderError.invalidInputFormat
        }
        
        // Create desired output format (16kHz Mono PCM Int16)
        guard let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: outputSampleRate,
            channels: outputChannels,
            interleaved: false
        ) else {
            logger.error("Failed to create desired recording format")
            throw AudioRecorderError.invalidRecordingFormat
        }
        
        // Prepare output file
        let createdAudioFile: AVAudioFile
        do {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            
            createdAudioFile = try AVAudioFile(
                forWriting: outputURL,
                settings: desiredFormat.settings,
                commonFormat: desiredFormat.commonFormat,
                interleaved: desiredFormat.isInterleaved
            )
        } catch {
            logger.error("Failed to create audio file: \(error.localizedDescription)")
            throw AudioRecorderError.failedToCreateFile(error)
        }
        
        // Create format converter
        guard let audioConverter = AVAudioConverter(from: inputFormat, to: desiredFormat) else {
            logger.error("Failed to create audio format converter")
            throw AudioRecorderError.failedToCreateConverter
        }
        
        // Store references (thread-safe)
        fileWriteLock.lock()
        recordingFormat = desiredFormat
        audioFile = createdAudioFile
        converter = audioConverter
        currentRecordingURL = outputURL
        fileWriteLock.unlock()
        
        // Install tap on input node
        input.installTap(onBus: tapBusNumber, bufferSize: tapBufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.audioProcessingQueue.async {
                self.processAudioBuffer(buffer)
            }
        }
        
        // Prepare and start engine
        engine.prepare()
        
        do {
            try engine.start()
            isRecording = true
            startValidationTimer(url: outputURL, retryCount: retryCount)
            logger.info("Audio engine started successfully")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            input.removeTap(onBus: tapBusNumber)
            throw AudioRecorderError.failedToStartEngine(error)
        }
    }
    
    /// Stop recording and finalize the audio file.
    @discardableResult
    public func stopRecording() -> URL? {
        guard isRecording else { return currentRecordingURL }
        
        logger.info("Stopping recording...")
        
        // Cancel validation timer
        validationTimer?.invalidate()
        validationTimer = nil
        
        // Remove tap and stop engine
        inputNode?.removeTap(onBus: tapBusNumber)
        audioEngine?.stop()
        
        // Wait for processing queue to finish
        audioProcessingQueue.sync {}
        
        // Clean up file resources
        fileWriteLock.lock()
        let url = currentRecordingURL
        audioFile = nil
        converter = nil
        recordingFormat = nil
        fileWriteLock.unlock()
        
        // Reset state
        audioEngine = nil
        inputNode = nil
        isRecording = false
        hasReceivedValidBuffer = false
        currentAveragePower = -160.0
        currentPeakPower = -160.0
        
        if let url = url {
            verifyFileIntegrity(url: url)
        }
        
        return url
    }
    
    // MARK: - Permission Checking
    
    public func hasPermission() async -> Bool {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return micStatus == .authorized
    }
    
    /// Returns the detailed permission state for the microphone.
    public func getPermissionState() -> PermissionState {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }
    
    public func requestPermission() async {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
    
    public func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func startValidationTimer(url: URL, retryCount: Int) {
        validationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                let validationPassed = self.hasReceivedValidBuffer
                
                if !validationPassed {
                    self.logger.warning("Recording validation failed - no valid buffers received")
                    _ = self.stopRecording()
                    
                    if retryCount < 2 {
                        self.logger.info("Retrying recording (attempt \(retryCount + 1)/2)...")
                        try? await Task.sleep(for: .milliseconds(500))
                        do {
                            try self.startRecording(to: url, retryCount: retryCount + 1)
                        } catch {
                            self.logger.error("Retry failed: \(error.localizedDescription)")
                            self.error = error
                            self.onRecordingError?(error)
                        }
                    } else {
                        self.logger.error("Recording failed after 2 retry attempts")
                        let error = AudioRecorderError.recordingValidationFailed
                        self.error = error
                        self.onRecordingError?(error)
                    }
                } else {
                    self.logger.info("Recording validation successful")
                }
            }
        }
    }
    
    nonisolated private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        updateMeters(from: buffer)
        writeBufferToFile(buffer)
    }
    
    nonisolated private func writeBufferToFile(_ buffer: AVAudioPCMBuffer) {
        fileWriteLock.lock()
        defer { fileWriteLock.unlock() }
        
        guard let audioFile = audioFile,
              let converter = converter,
              let format = recordingFormat else { return }
        
        guard buffer.frameLength > 0 else {
            logger.error("Empty buffer received")
            return
        }
        
        // Calculate output capacity based on sample rate ratio
        let inputSampleRate = buffer.format.sampleRate
        let outputSampleRate = format.sampleRate
        let ratio = outputSampleRate / inputSampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputCapacity) else {
            logger.error("Failed to create converted buffer")
            return
        }
        
        var error: NSError?
        let state = ConverterState()
        
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if state.hasProvidedBuffer {
                outStatus.pointee = .noDataNow
                return nil
            } else {
                state.hasProvidedBuffer = true
                outStatus.pointee = .haveData
                return buffer
            }
        }
        
        if let error = error {
            logger.error("Audio conversion failed: \(error.localizedDescription)")
            return
        }
        
        do {
            try audioFile.write(from: convertedBuffer)
            Task { @MainActor in
                if !self.hasReceivedValidBuffer {
                    self.hasReceivedValidBuffer = true
                }
            }
        } catch {
            logger.error("File write failed: \(error.localizedDescription)")
        }
    }
    
    nonisolated private func updateMeters(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        guard channelCount > 0, frameLength > 0 else { return }
        
        let channel = channelData[0]
        var sum: Float = 0.0
        var peak: Float = 0.0
        
        for frame in 0..<frameLength {
            let sample = channel[frame]
            let absSample = abs(sample)
            
            if absSample > peak {
                peak = absSample
            }
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let averagePowerDb = 20.0 * log10(max(rms, 0.000001))
        let peakPowerDb = 20.0 * log10(max(peak, 0.000001))
        
        Task { @MainActor in
            self.currentAveragePower = averagePowerDb
            self.currentPeakPower = peakPowerDb
        }
    }
    
    private func verifyFileIntegrity(url: URL) {
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                logger.info("Recording saved: \(url.lastPathComponent) (\(duration.seconds)s)")
            } catch {
                logger.error("Verification failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Errors

public enum AudioRecorderError: LocalizedError {
    case invalidInputFormat
    case invalidRecordingFormat
    case failedToCreateFile(Error)
    case failedToCreateConverter
    case failedToStartEngine(Error)
    case audioConversionError(Error)
    case fileWriteFailed(Error)
    case recordingValidationFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidInputFormat:
            return "Invalid audio input format from device"
        case .invalidRecordingFormat:
            return "Failed to create recording format"
        case .failedToCreateFile(let error):
            return "Failed to create audio file: \(error.localizedDescription)"
        case .failedToCreateConverter:
            return "Failed to create audio format converter"
        case .failedToStartEngine(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .audioConversionError(let error):
            return "Audio format conversion failed: \(error.localizedDescription)"
        case .fileWriteFailed(let error):
            return "Failed to write audio data to file: \(error.localizedDescription)"
        case .recordingValidationFailed:
            return "Recording failed to start - no valid audio received from device"
        }
    }
}

// MARK: - Helper Classes

/// Thread-safe state for audio converter callback.
/// Used to avoid capturing mutable variables in sendable closures.
private final class ConverterState: @unchecked Sendable {
    var hasProvidedBuffer = false
}
