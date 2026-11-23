import Foundation

struct TextCleanupOptions: Codable, Equatable, Sendable {
  var removeFillers: Bool
  var removeRepeatedWords: Bool
  var applySpokenLineBreaks: Bool

  static let `default` = TextCleanupOptions(
    removeFillers: true,
    removeRepeatedWords: true,
    applySpokenLineBreaks: true
  )

  var isEnabled: Bool { removeFillers || removeRepeatedWords || applySpokenLineBreaks }
}
