import AVFoundation
import XCTest

@testable import Scribe

final class RecordingWriterTests: XCTestCase {
  private let inputRate = 48_000.0
  private let bufferFrames: AVAudioFrameCount = 4_800
  private var url: URL!

  override func setUp() {
    url = FileManager.default.temporaryDirectory
      .appendingPathComponent("RecordingWriterTests-\(UUID().uuidString).wav")
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: url)
  }

  func testWritesSixteenKilohertzMonoAndMeasuresPeak() throws {
    let result = try record(seconds: 1) { Float(0.5 * sin(2 * .pi * 440 * $0)) }

    let file = try AVAudioFile(forReading: url)
    XCTAssertEqual(file.fileFormat.sampleRate, Double(AudioPreprocessor.sampleRate))
    XCTAssertEqual(file.fileFormat.channelCount, 1)
    XCTAssertEqual(Double(file.length), Double(AudioPreprocessor.sampleRate), accuracy: 100)
    XCTAssertEqual(result.duration, 1, accuracy: 0.01)
    XCTAssertEqual(result.level.peak, 0.5, accuracy: 0.01)
    XCTAssertFalse(result.level.isClipped)
  }

  func testDetectsClipping() throws {
    let result = try record(seconds: 0.5) { sin(2 * .pi * 200 * $0) >= 0 ? 1 : -1 }
    XCTAssertTrue(result.level.isClipped)
  }

  private func record(seconds: Double, signal: (Double) -> Float) throws -> RecordingWriter.Result {
    let format = try XCTUnwrap(
      AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: inputRate, channels: 2, interleaved: false))
    let writer = try RecordingWriter(url: url, inputFormat: format)
    var frame = 0
    for _ in 0..<Int(seconds * inputRate / Double(bufferFrames)) {
      let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrames))
      buffer.frameLength = bufferFrames
      let channels = try XCTUnwrap(buffer.floatChannelData)
      for index in 0..<Int(bufferFrames) {
        let sample = signal(Double(frame + index) / inputRate)
        channels[0][index] = sample
        channels[1][index] = sample
      }
      frame += Int(bufferFrames)
      writer.append(buffer)
    }
    return try writer.finish()
  }
}
