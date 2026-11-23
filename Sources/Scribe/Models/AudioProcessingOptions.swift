import Foundation

struct AudioProcessingOptions: Codable, Equatable, Sendable {
  var removeLowHum: Bool
  var normalizeLevel: Bool
  var trimSilence: Bool

  static let `default` = AudioProcessingOptions(
    removeLowHum: true,
    normalizeLevel: true,
    trimSilence: true
  )

  var isEnabled: Bool { removeLowHum || normalizeLevel || trimSilence }
}
