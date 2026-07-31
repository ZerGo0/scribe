import AVFoundation
import XCTest

@testable import Scribe

final class MP3EncoderTests: XCTestCase {
  func testEncodesRecordedWAVToMP3() throws {
    let inputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("wav")
    let outputURL = inputURL.deletingPathExtension().appendingPathExtension("mp3")
    defer {
      removeIfPresent(inputURL)
      removeIfPresent(outputURL)
    }

    try writeRecordedWAV(to: inputURL)

    let encodedURL = try MP3Encoder.encode(inputURL)

    XCTAssertEqual(encodedURL, outputURL)
    XCTAssertGreaterThan(try Data(contentsOf: encodedURL).count, 0)
    XCTAssertGreaterThan(try AVAudioFile(forReading: encodedURL).length, 0)
  }

  private func writeRecordedWAV(to url: URL) throws {
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVSampleRateKey: 16_000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
    ]
    let file = try AVAudioFile(forWriting: url, settings: settings)
    let format = file.processingFormat
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: 1_600
      )
    else {
      XCTFail("Could not allocate the fixture buffer.")
      return
    }
    buffer.frameLength = buffer.frameCapacity
    if let samples = buffer.floatChannelData?[0] {
      for frame in 0..<Int(buffer.frameLength) {
        samples[frame] = sin(Float(frame) * 0.05)
      }
    }
    try file.write(from: buffer)
  }

  private func removeIfPresent(_ url: URL) {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try? FileManager.default.removeItem(at: url)
  }
}
