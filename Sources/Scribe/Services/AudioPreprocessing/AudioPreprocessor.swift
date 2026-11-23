import AVFoundation
import Accelerate
import FluidAudio
import Foundation

enum AudioPreprocessor {
  static let sampleRate = 16_000
  private static let highPassCutoffHz = 80.0
  private static let butterworthQ = 1 / 2.0.squareRoot()
  private static let targetPeakDecibels: Float = -3
  private static let maximumGainDecibels: Float = 30
  private static let maximumChunkSeconds = 30.0
  private static let maximumPauseSeconds = 0.5

  static func speechChunks(from url: URL, options: AudioProcessingOptions) async throws -> [[Float]] {
    var samples = try AudioConverter().resampleAudioFile(url)
    if options.removeLowHum { samples = highPassFiltered(samples) }
    if options.normalizeLevel { samples = normalized(samples) }
    guard options.trimSilence else { return samples.isEmpty ? [] : [samples] }

    let vad = try await VadManager()
    let segments = try await vad.segmentSpeech(
      samples,
      config: VadSegmentationConfig(maxSpeechDuration: maximumChunkSeconds)
    )
    return chunks(
      samples,
      speechRanges: segments.map {
        $0.startSample(sampleRate: sampleRate)..<$0.endSample(sampleRate: sampleRate)
      },
      maximumChunkSamples: sampleCount(seconds: maximumChunkSeconds),
      maximumPauseSamples: sampleCount(seconds: maximumPauseSeconds)
    )
  }

  static func processedFile(from url: URL, options: AudioProcessingOptions) async throws -> URL {
    guard options.isEnabled else { return url }
    let chunks = try await speechChunks(from: url, options: options)
    guard !chunks.isEmpty else { throw DictationError.noSpeechDetected }
    let outputURL = url.deletingPathExtension()
      .appendingPathExtension("processed")
      .appendingPathExtension("wav")
    try writeWAV(joined(chunks), to: outputURL)
    return outputURL
  }

  static func highPassFiltered(
    _ samples: [Float],
    cutoffHz: Double = highPassCutoffHz,
    sampleRate: Double = Double(sampleRate)
  ) -> [Float] {
    guard !samples.isEmpty else { return samples }
    let omega = 2 * Double.pi * cutoffHz / sampleRate
    let alpha = sin(omega) / (2 * butterworthQ)
    let cosine = cos(omega)
    let a0 = 1 + alpha
    let coefficients = [
      (1 + cosine) / 2 / a0,
      -(1 + cosine) / a0,
      (1 + cosine) / 2 / a0,
      -2 * cosine / a0,
      (1 - alpha) / a0,
    ]
    guard
      var biquad = vDSP.Biquad(
        coefficients: coefficients,
        channelCount: 1,
        sectionCount: 1,
        ofType: Float.self
      )
    else { return samples }
    return biquad.apply(input: samples)
  }

  static func normalized(_ samples: [Float], peakDecibels: Float = targetPeakDecibels) -> [Float] {
    let peak = vDSP.maximumMagnitude(samples)
    guard peak > 0 else { return samples }
    let gain = min(
      decibelsToAmplitude(peakDecibels) / peak,
      decibelsToAmplitude(maximumGainDecibels)
    )
    return vDSP.multiply(gain, samples)
  }

  static func chunks(
    _ samples: [Float],
    speechRanges: [Range<Int>],
    maximumChunkSamples: Int,
    maximumPauseSamples: Int
  ) -> [[Float]] {
    var result: [[Float]] = []
    var current: [Float] = []
    var previousEnd: Int?

    for range in speechRanges {
      let start = max(range.lowerBound, previousEnd ?? 0, 0)
      let end = min(range.upperBound, samples.count)
      guard start < end else { continue }

      var pause: [Float] = []
      if let previousEnd {
        let gap = start - previousEnd
        pause =
          gap <= maximumPauseSamples
          ? Array(samples[previousEnd..<start])
          : Array(repeating: 0, count: maximumPauseSamples)
      }
      let speech = samples[start..<end]

      if !current.isEmpty, current.count + pause.count + speech.count > maximumChunkSamples {
        result.append(current)
        current = Array(speech)
      } else {
        current.append(contentsOf: pause)
        current.append(contentsOf: speech)
      }
      previousEnd = end
    }

    if !current.isEmpty { result.append(current) }
    return result
  }

  static func joined(_ chunks: [[Float]]) -> [Float] {
    let pause = [Float](repeating: 0, count: sampleCount(seconds: maximumPauseSeconds))
    return Array(chunks.joined(separator: pause))
  }

  private static func writeWAV(_ samples: [Float], to url: URL) throws {
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
    ]
    let file = try AVAudioFile(
      forWriting: url,
      settings: settings,
      commonFormat: .pcmFormatFloat32,
      interleaved: false
    )
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat,
        frameCapacity: AVAudioFrameCount(samples.count)
      ),
      let channel = buffer.floatChannelData?[0]
    else {
      throw DictationError.recordingFailed("Could not allocate an audio buffer.")
    }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
    try file.write(from: buffer)
  }

  private static func sampleCount(seconds: Double) -> Int {
    Int(seconds * Double(sampleRate))
  }

  private static func decibelsToAmplitude(_ decibels: Float) -> Float {
    powf(10, decibels / 20)
  }
}
