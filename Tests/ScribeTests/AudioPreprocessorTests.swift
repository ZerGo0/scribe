import Foundation
import XCTest

@testable import Scribe

final class AudioPreprocessorTests: XCTestCase {
  private let sampleRate = Double(AudioPreprocessor.sampleRate)

  func testHighPassRemovesHumAndKeepsSpeechBand() {
    let hum = sine(frequency: 20, seconds: 1)
    let voice = sine(frequency: 1_000, seconds: 1)
    let settle = Int(sampleRate / 10)

    let filteredHum = AudioPreprocessor.highPassFiltered(hum).dropFirst(settle)
    let filteredVoice = AudioPreprocessor.highPassFiltered(voice).dropFirst(settle)

    XCTAssertLessThan(peak(filteredHum), 0.1)
    XCTAssertGreaterThan(peak(filteredVoice), 0.95)
  }

  func testNormalizationRaisesPeakToMinusThreeDecibels() {
    let quiet = sine(frequency: 440, seconds: 0.5).map { $0 * 0.1 }
    let normalized = AudioPreprocessor.normalized(quiet)
    XCTAssertEqual(peak(normalized[...]), powf(10, -3.0 / 20), accuracy: 0.001)
  }

  func testNormalizationLeavesSilenceUnchanged() {
    let silence = [Float](repeating: 0, count: 100)
    XCTAssertEqual(AudioPreprocessor.normalized(silence), silence)
  }

  func testChunksKeepShortPausesAndShortenLongPauses() {
    let samples = (0..<100).map(Float.init)
    let chunks = AudioPreprocessor.chunks(
      samples,
      speechRanges: [0..<10, 12..<20, 60..<70],
      maximumChunkSamples: 100,
      maximumPauseSamples: 5
    )

    XCTAssertEqual(chunks.count, 1)
    XCTAssertEqual(Array(chunks[0][0..<20]), Array(samples[0..<20]))
    XCTAssertEqual(Array(chunks[0][20..<25]), [0, 0, 0, 0, 0])
    XCTAssertEqual(Array(chunks[0][25..<35]), Array(samples[60..<70]))
  }

  func testChunksSplitAtPausesWhenTooLong() {
    let samples = [Float](repeating: 1, count: 100)
    let chunks = AudioPreprocessor.chunks(
      samples,
      speechRanges: [0..<30, 32..<60, 62..<90],
      maximumChunkSamples: 64,
      maximumPauseSamples: 5
    )

    XCTAssertEqual(chunks.map(\.count), [60, 28])
  }

  func testChunksClampRangesToAudio() {
    let chunks = AudioPreprocessor.chunks(
      [1, 2, 3],
      speechRanges: [-5..<2, 1..<10],
      maximumChunkSamples: 100,
      maximumPauseSamples: 5
    )
    XCTAssertEqual(chunks, [[1, 2, 3]])
  }

  private func sine(frequency: Double, seconds: Double) -> [Float] {
    (0..<Int(seconds * sampleRate)).map {
      Float(sin(2 * Double.pi * frequency * Double($0) / sampleRate))
    }
  }

  private func peak(_ samples: ArraySlice<Float>) -> Float {
    samples.map(abs).max() ?? 0
  }
}
