import AVFoundation
@testable import MeetingAssistantCoreAudio
import XCTest

final class AudioRecordingWorkerMeteringTests: XCTestCase {
    func testMakeMeterSnapshot_ComputesPerBucketRMSFromCurrentBuffer() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8))
        buffer.frameLength = 8

        guard let channelData = buffer.floatChannelData else {
            return XCTFail("Expected float channel data")
        }

        let ch0: [Float] = [1, 1, 1, 1, 0, 0, 0, 0]
        let ch1: [Float] = [0, 0, 0, 0, 0.5, 0.5, 0.5, 0.5]

        for frame in 0..<8 {
            channelData[0][frame] = ch0[frame]
            channelData[1][frame] = ch1[frame]
        }

        let snapshot = AudioRecordingWorker.makeMeterSnapshot(from: buffer, barCount: 2)
        let unwrapped = try XCTUnwrap(snapshot)

        XCTAssertEqual(unwrapped.barPowerDBLevels.count, 2)
        XCTAssertEqual(unwrapped.peakPowerDB, 0.0, accuracy: 0.001)

        XCTAssertGreaterThan(unwrapped.barPowerDBLevels[0], -0.5)
        XCTAssertLessThan(unwrapped.barPowerDBLevels[1], -5.5)
        XCTAssertGreaterThan(unwrapped.barPowerDBLevels[1], -6.5)

        XCTAssertLessThan(unwrapped.averagePowerDB, -2.5)
        XCTAssertGreaterThan(unwrapped.averagePowerDB, -3.8)
    }

    func testMakeMeterSnapshot_WithZeroBarCount_ReturnsOnlyGlobalMeters() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        buffer.frameLength = 4
        buffer.floatChannelData?[0][0] = 0.25
        buffer.floatChannelData?[0][1] = 0.25
        buffer.floatChannelData?[0][2] = 0.25
        buffer.floatChannelData?[0][3] = 0.25

        let snapshot = try XCTUnwrap(AudioRecordingWorker.makeMeterSnapshot(from: buffer, barCount: 0))

        XCTAssertTrue(snapshot.barPowerDBLevels.isEmpty)
        XCTAssertLessThan(snapshot.averagePowerDB, 0.0)
        XCTAssertGreaterThan(snapshot.peakPowerDB, -13.0)
    }
}
