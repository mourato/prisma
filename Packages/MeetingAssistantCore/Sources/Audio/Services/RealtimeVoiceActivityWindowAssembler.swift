@preconcurrency import AVFoundation
import Foundation

public actor RealtimeVoiceActivityWindowAssembler {
    public struct Window: Sendable {
        public let startTime: Double
        public let endTime: Double
        public let samples: [Float]

        public init(startTime: Double, endTime: Double, samples: [Float]) {
            self.startTime = startTime
            self.endTime = endTime
            self.samples = samples
        }
    }

    private struct Frame {
        let startSample: Int64
        let samples: [Float]
        let isVoice: Bool

        var endSample: Int64 {
            startSample + Int64(samples.count)
        }
    }

    private enum Constants {
        static let sampleRate = 16_000.0
        static let sampleRateInt = 16_000
        static let frameDurationSeconds = 0.03
        static let frameSampleCount = Int(Constants.sampleRate * Constants.frameDurationSeconds)
        static let speechThresholdDB: Float = -48
        static let speechStartFrameCount = 6
        static let speechEndFrameCount = 15
        static let preRollFrameCount = 7
        static let tailFrameCount = 8
        static let commitSpokenFrameCount = 400
    }

    private var absoluteSampleCursor: Int64 = 0
    private var sampleRemainder: [Float] = []
    private var recentFrames: [Frame] = []
    private var activeFrames: [Frame] = []
    private var consecutiveVoiceFrames = 0
    private var consecutiveSilentFrames = 0
    private var activeSpeech = false
    private var spokenFramesInCurrentChunk = 0

    public init() {}

    public func append(buffer: AVAudioPCMBuffer) throws -> [Window] {
        let convertedSamples = try convertTo16kHzMonoSamples(buffer: buffer)
        guard !convertedSamples.isEmpty else { return [] }

        sampleRemainder.append(contentsOf: convertedSamples)

        var emittedWindows: [Window] = []
        while sampleRemainder.count >= Constants.frameSampleCount {
            let frameSamples = Array(sampleRemainder.prefix(Constants.frameSampleCount))
            sampleRemainder.removeFirst(Constants.frameSampleCount)

            let frame = Frame(
                startSample: absoluteSampleCursor,
                samples: frameSamples,
                isVoice: Self.isVoiceFrame(frameSamples)
            )
            absoluteSampleCursor += Int64(Constants.frameSampleCount)

            emittedWindows.append(contentsOf: process(frame: frame))
        }

        return emittedWindows
    }

    public func finish() throws -> [Window] {
        var emittedWindows: [Window] = []

        if !sampleRemainder.isEmpty {
            let paddedSamples = sampleRemainder + Array(
                repeating: 0,
                count: max(0, Constants.frameSampleCount - sampleRemainder.count)
            )
            let frame = Frame(
                startSample: absoluteSampleCursor,
                samples: paddedSamples,
                isVoice: Self.isVoiceFrame(sampleRemainder)
            )
            absoluteSampleCursor += Int64(Constants.frameSampleCount)
            emittedWindows.append(contentsOf: process(frame: frame))
            sampleRemainder.removeAll(keepingCapacity: false)
        }

        if activeSpeech, let window = makeWindow(from: activeFrames, trimTrailingSilentFrames: 0) {
            emittedWindows.append(window)
        }

        resetState()
        return emittedWindows
    }

    private func process(frame: Frame) -> [Window] {
        recentFrames.append(frame)
        if recentFrames.count > Constants.preRollFrameCount {
            recentFrames.removeFirst(recentFrames.count - Constants.preRollFrameCount)
        }

        var emittedWindows: [Window] = []

        if activeSpeech {
            activeFrames.append(frame)

            if frame.isVoice {
                consecutiveSilentFrames = 0
                spokenFramesInCurrentChunk += 1
            } else {
                consecutiveSilentFrames += 1
            }

            if spokenFramesInCurrentChunk >= Constants.commitSpokenFrameCount,
               let window = makeWindow(from: activeFrames, trimTrailingSilentFrames: 0)
            {
                emittedWindows.append(window)
                activeFrames.removeAll(keepingCapacity: true)
                spokenFramesInCurrentChunk = 0
                consecutiveSilentFrames = 0
            } else if consecutiveSilentFrames >= Constants.speechEndFrameCount {
                let trimCount = max(0, consecutiveSilentFrames - Constants.tailFrameCount)
                if let window = makeWindow(from: activeFrames, trimTrailingSilentFrames: trimCount) {
                    emittedWindows.append(window)
                }
                activeSpeech = false
                activeFrames.removeAll(keepingCapacity: true)
                spokenFramesInCurrentChunk = 0
                consecutiveVoiceFrames = 0
                consecutiveSilentFrames = 0
            }

            return emittedWindows
        }

        if frame.isVoice {
            consecutiveVoiceFrames += 1
        } else {
            consecutiveVoiceFrames = 0
        }

        if consecutiveVoiceFrames >= Constants.speechStartFrameCount {
            activeSpeech = true
            activeFrames = recentFrames
            spokenFramesInCurrentChunk = activeFrames.reduce(into: 0) { partialResult, frame in
                if frame.isVoice {
                    partialResult += 1
                }
            }
            consecutiveSilentFrames = 0
        }

        return emittedWindows
    }

    private func makeWindow(from frames: [Frame], trimTrailingSilentFrames: Int) -> Window? {
        guard !frames.isEmpty else { return nil }

        let keepCount = max(0, frames.count - trimTrailingSilentFrames)
        let keptFrames = Array(frames.prefix(keepCount))
        guard !keptFrames.isEmpty else { return nil }

        let startSample = keptFrames[0].startSample
        let endSample = keptFrames[keptFrames.count - 1].endSample
        let samples = keptFrames.flatMap(\.samples)
        guard !samples.isEmpty else { return nil }

        return Window(
            startTime: Double(startSample) / Constants.sampleRate,
            endTime: Double(endSample) / Constants.sampleRate,
            samples: samples
        )
    }

    private func resetState() {
        absoluteSampleCursor = 0
        sampleRemainder.removeAll(keepingCapacity: false)
        recentFrames.removeAll(keepingCapacity: false)
        activeFrames.removeAll(keepingCapacity: false)
        consecutiveVoiceFrames = 0
        consecutiveSilentFrames = 0
        activeSpeech = false
        spokenFramesInCurrentChunk = 0
    }

    private func convertTo16kHzMonoSamples(buffer: AVAudioPCMBuffer) throws -> [Float] {
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Constants.sampleRate,
                channels: 1,
                interleaved: false
            )
        else {
            throw RealtimeVoiceActivityError.conversionFailed
        }

        let workingBuffer: AVAudioPCMBuffer
        if buffer.format.sampleRate == Constants.sampleRate,
           buffer.format.channelCount == 1,
           buffer.format.commonFormat == .pcmFormatFloat32,
           !buffer.format.isInterleaved
        {
            workingBuffer = buffer
        } else {
            guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
                throw RealtimeVoiceActivityError.conversionFailed
            }

            let targetFrameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * Constants.sampleRate / buffer.format.sampleRate
            ) + 1

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: targetFrameCapacity
            ) else {
                throw RealtimeVoiceActivityError.conversionFailed
            }

            var conversionError: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &conversionError, withInputFrom: inputBlock)
            if let conversionError {
                throw conversionError
            }

            workingBuffer = convertedBuffer
        }

        guard let channelData = workingBuffer.floatChannelData else { return [] }
        let frameCount = Int(workingBuffer.frameLength)
        guard frameCount > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
    }

    private static func isVoiceFrame(_ samples: [Float]) -> Bool {
        guard !samples.isEmpty else { return false }

        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }

        let rms = sqrt(sumSquares / Float(samples.count))
        guard rms > 0 else { return false }
        let db = 20 * log10(rms)
        return db >= Constants.speechThresholdDB
    }
}

public enum RealtimeVoiceActivityError: Error {
    case conversionFailed
}
