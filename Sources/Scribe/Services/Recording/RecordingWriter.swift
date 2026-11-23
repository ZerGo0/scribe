import AVFoundation
import Foundation

final class RecordingWriter {
  struct Result {
    let url: URL
    let duration: TimeInterval
    let level: InputLevel
  }

  private static let clippingAmplitude: Float = 0.99
  private static let clippedRunFrames = 3
  private static let drainFrameCapacity: AVAudioFrameCount = 4_096

  let url: URL
  private let file: AVAudioFile
  private let converter: AVAudioConverter
  private let outputFormat: AVAudioFormat
  private var writtenFrames: AVAudioFramePosition = 0
  private var peak: Float = 0
  private var clippedRun = 0
  private var isClipped = false
  private var writeError: Error?

  init(url: URL, inputFormat: AVAudioFormat) throws {
    guard
      let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(AudioPreprocessor.sampleRate),
        channels: 1,
        interleaved: false
      ),
      let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
    else {
      throw DictationError.recordingFailed("The microphone format is not supported.")
    }
    converter.downmix = true
    converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
    converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering

    self.url = url
    self.outputFormat = outputFormat
    self.converter = converter
    file = try AVAudioFile(
      forWriting: url,
      settings: [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: AudioPreprocessor.sampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
      ],
      commonFormat: .pcmFormatFloat32,
      interleaved: false
    )
  }

  func append(_ buffer: AVAudioPCMBuffer) {
    measure(buffer)
    convert(buffer)
  }

  func finish() throws -> Result {
    convert(nil)
    if let writeError { throw writeError }
    return Result(
      url: url,
      duration: Double(writtenFrames) / outputFormat.sampleRate,
      level: InputLevel(peak: peak, isClipped: isClipped)
    )
  }

  func discard() {
    try? FileManager.default.removeItem(at: url)
  }

  private func measure(_ buffer: AVAudioPCMBuffer) {
    guard let channels = buffer.floatChannelData else { return }
    let frameCount = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    let isInterleaved = buffer.format.isInterleaved
    for frame in 0..<frameCount {
      var loudest: Float = 0
      for channel in 0..<channelCount {
        let sample =
          isInterleaved ? channels[0][frame * channelCount + channel] : channels[channel][frame]
        loudest = max(loudest, abs(sample))
      }
      peak = max(peak, loudest)
      clippedRun = loudest >= Self.clippingAmplitude ? clippedRun + 1 : 0
      if clippedRun >= Self.clippedRunFrames { isClipped = true }
    }
  }

  private func convert(_ buffer: AVAudioPCMBuffer?) {
    guard writeError == nil else { return }
    let ratio = outputFormat.sampleRate / converter.inputFormat.sampleRate
    let capacity =
      AVAudioFrameCount((Double(buffer?.frameLength ?? 0) * ratio).rounded(.up))
      + Self.drainFrameCapacity
    var delivered = false

    while true {
      guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
        return
      }
      var error: NSError?
      let status = converter.convert(to: output, error: &error) { _, inputStatus in
        guard let buffer else {
          inputStatus.pointee = .endOfStream
          return nil
        }
        guard !delivered else {
          inputStatus.pointee = .noDataNow
          return nil
        }
        delivered = true
        inputStatus.pointee = .haveData
        return buffer
      }
      if let error {
        writeError = error
        return
      }
      if output.frameLength > 0 {
        do {
          try file.write(from: output)
          writtenFrames += AVAudioFramePosition(output.frameLength)
        } catch {
          writeError = error
          return
        }
      }
      guard status == .haveData else { return }
    }
  }
}
