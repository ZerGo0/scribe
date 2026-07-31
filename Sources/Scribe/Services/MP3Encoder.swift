import AVFoundation
import Foundation
import LAME

enum MP3Encoder {
  private static let bitRateKbps: Int32 = 64
  private static let framesPerBuffer: AVAudioFrameCount = 8_192

  static func encode(_ inputURL: URL) throws -> URL {
    let outputURL = inputURL.deletingPathExtension().appendingPathExtension("mp3")
    try? FileManager.default.removeItem(at: outputURL)

    do {
      try encode(inputURL: inputURL, outputURL: outputURL)
      return outputURL
    } catch {
      try? FileManager.default.removeItem(at: outputURL)
      throw DictationError.recordingFailed(
        "MP3 encoding failed: \(error.localizedDescription)"
      )
    }
  }

  private static func encode(inputURL: URL, outputURL: URL) throws {
    let input = try AVAudioFile(forReading: inputURL)
    let format = input.processingFormat
    guard format.channelCount == 1, format.sampleRate == 16_000 else {
      throw EncodingError.unsupportedInput
    }
    guard let lame = lame_init() else {
      throw EncodingError.initializationFailed
    }
    defer { lame_close(lame) }

    try configure(lame)
    guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
      throw EncodingError.outputCreationFailed
    }
    let output = try FileHandle(forWritingTo: outputURL)
    defer { try? output.close() }

    guard
      let pcm = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: framesPerBuffer
      )
    else {
      throw EncodingError.bufferAllocationFailed
    }
    var encoded = [UInt8](
      repeating: 0,
      count: Int(Double(framesPerBuffer) * 1.25) + 7_200
    )

    while input.framePosition < input.length {
      let remainingFrames = input.length - input.framePosition
      let frameCount = AVAudioFrameCount(
        min(AVAudioFramePosition(framesPerBuffer), remainingFrames)
      )
      try input.read(into: pcm, frameCount: frameCount)
      guard let samples = pcm.floatChannelData?[0] else {
        throw EncodingError.missingPCMData
      }
      let byteCount = lame_encode_buffer_ieee_float(
        lame,
        samples,
        samples,
        Int32(pcm.frameLength),
        &encoded,
        Int32(encoded.count)
      )
      try write(encoded, count: byteCount, to: output)
    }

    let finalByteCount = lame_encode_flush(lame, &encoded, Int32(encoded.count))
    try write(encoded, count: finalByteCount, to: output)
  }

  private static func configure(_ lame: OpaquePointer) throws {
    guard lame_set_in_samplerate(lame, 16_000) == 0,
      lame_set_num_channels(lame, 1) == 0,
      lame_set_brate(lame, bitRateKbps) == 0,
      lame_set_quality(lame, 2) == 0,
      lame_init_params(lame) == 0
    else {
      throw EncodingError.configurationFailed
    }
  }

  private static func write(
    _ bytes: [UInt8],
    count: Int32,
    to output: FileHandle
  ) throws {
    guard count >= 0 else {
      throw EncodingError.encoderFailed(count)
    }
    if count > 0 {
      try output.write(contentsOf: bytes.prefix(Int(count)))
    }
  }

  private enum EncodingError: LocalizedError {
    case unsupportedInput
    case initializationFailed
    case configurationFailed
    case outputCreationFailed
    case bufferAllocationFailed
    case missingPCMData
    case encoderFailed(Int32)

    var errorDescription: String? {
      switch self {
      case .unsupportedInput: "Expected 16 kHz mono audio."
      case .initializationFailed: "Could not initialize the MP3 encoder."
      case .configurationFailed: "Could not configure the MP3 encoder."
      case .outputCreationFailed: "Could not create the MP3 output file."
      case .bufferAllocationFailed: "Could not allocate an audio buffer."
      case .missingPCMData: "The recording did not contain readable PCM audio."
      case .encoderFailed(let code): "The MP3 encoder failed with code \(code)."
      }
    }
  }
}
