import Carbon
import Foundation

struct ProviderConfiguration: Codable, Equatable, Sendable {
  var baseURL: String
  var model: String

  static let `default` = ProviderConfiguration(
    baseURL: "https://api.openai.com/v1",
    model: "gpt-4o-mini-transcribe"
  )

  var normalizedBaseURL: URL? {
    let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard var components = URLComponents(string: trimmed),
      components.scheme == "https" || components.scheme == "http",
      components.host != nil
    else {
      return nil
    }
    while components.path.count > 1, components.path.hasSuffix("/") {
      components.path.removeLast()
    }
    return components.url
  }
}

struct HotKeyConfiguration: Codable, Equatable, Sendable {
  var keyCode: UInt32
  var carbonModifiers: UInt32

  static let `default` = HotKeyConfiguration(
    keyCode: UInt32(kVK_Space),
    carbonModifiers: UInt32(optionKey)
  )
}

struct Transcript: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  let text: String
  let createdAt: Date
  let duration: TimeInterval

  init(id: UUID = UUID(), text: String, createdAt: Date = Date(), duration: TimeInterval) {
    self.id = id
    self.text = text
    self.createdAt = createdAt
    self.duration = duration
  }
}

enum DictationError: LocalizedError, Equatable {
  case invalidProviderURL
  case missingAPIKey
  case microphoneDenied
  case accessibilityDenied
  case emptyTranscript
  case recordingFailed(String)
  case requestFailed(String)

  var errorDescription: String? {
    switch self {
    case .invalidProviderURL: "Enter a valid provider base URL."
    case .missingAPIKey: "Add an API key in Settings."
    case .microphoneDenied: "Microphone permission is required."
    case .accessibilityDenied: "Accessibility permission is required to paste transcripts."
    case .emptyTranscript: "The provider returned an empty transcript."
    case .recordingFailed(let message): "Recording failed: \(message)"
    case .requestFailed(let message): "Transcription failed: \(message)"
    }
  }
}
