import Foundation

struct InputLevel: Equatable, Sendable {
  let peak: Float
  let isClipped: Bool
}

enum InputWarning: Equatable, Sendable {
  case clipped
  case quiet
  case bluetooth

  private static let quietPeak: Float = 0.01

  init?(level: InputLevel, usesBluetooth: Bool) {
    if level.isClipped {
      self = .clipped
    } else if level.peak < Self.quietPeak {
      self = .quiet
    } else if usesBluetooth {
      self = .bluetooth
    } else {
      return nil
    }
  }

  var message: String {
    switch self {
    case .clipped:
      "The microphone was too loud, so the sound was distorted. Lower the input volume in System Settings > Sound."
    case .quiet:
      "The microphone was very quiet. Raise the input volume in System Settings > Sound, or move closer to the microphone."
    case .bluetooth:
      "Bluetooth microphones record in low quality, which makes transcription less accurate. For better results, choose another microphone in System Settings > Sound."
    }
  }
}
